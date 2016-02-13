//
//  PBGitCommitController.m
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitCommitController.h"
#import "NSFileHandleExt.h"
#import "PBChangedFile.h"
#import "PBWebChangesController.h"
#import "PBGitIndex.h"
#import "PBNiceSplitView.h"
#import "PBGitRepositoryWatcher.h"
#import "PBCommitMessageView.h"

#import <ObjectiveGit/GTRepository.h>
#import <ObjectiveGit/GTConfiguration.h>

#define kCommitSplitViewPositionDefault @"Commit SplitView Position"

@interface PBGitCommitController ()
- (void)refreshFinished:(NSNotification *)notification;
- (void)commitWithVerification:(BOOL) doVerify;
- (void)commitStatusUpdated:(NSNotification *)notification;
- (void)commitFinished:(NSNotification *)notification;
- (void)commitFailed:(NSNotification *)notification;
- (void)commitHookFailed:(NSNotification *)notification;
- (void)amendCommit:(NSNotification *)notification;
- (void)indexChanged:(NSNotification *)notification;
- (void)indexOperationFailed:(NSNotification *)notification;
- (void)saveCommitSplitViewPosition;
@end

@implementation PBGitCommitController

@synthesize index;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	if (!(self = [super initWithRepository:theRepository superController:controller]))
		return nil;

	index = [[PBGitIndex alloc] initWithRepository:theRepository];
	[index refresh];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshFinished:) name:PBGitIndexFinishedIndexRefresh object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(commitStatusUpdated:) name:PBGitIndexCommitStatus object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(commitFinished:) name:PBGitIndexFinishedCommit object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(commitFailed:) name:PBGitIndexCommitFailed object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(commitHookFailed:) name:PBGitIndexCommitHookFailed object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(amendCommit:) name:PBGitIndexAmendMessageAvailable object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(indexChanged:) name:PBGitIndexIndexUpdated object:index];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(indexOperationFailed:) name:PBGitIndexOperationFailed object:index];

	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	commitMessageView.repository = self.repository;

	[commitMessageView setTypingAttributes:[NSDictionary dictionaryWithObject:[NSFont fontWithName:@"Monaco" size:12.0] forKey:NSFontAttributeName]];
	
	[unstagedFilesController setFilterPredicate:[NSPredicate predicateWithFormat:@"hasUnstagedChanges == 1"]];
	[cachedFilesController setFilterPredicate:[NSPredicate predicateWithFormat:@"hasStagedChanges == 1"]];
	
	[unstagedFilesController setSortDescriptors:[NSArray arrayWithObjects:
		[[NSSortDescriptor alloc] initWithKey:@"status" ascending:false],
		[[NSSortDescriptor alloc] initWithKey:@"path" ascending:true], nil]];
	[cachedFilesController setSortDescriptors:[NSArray arrayWithObject:
		[[NSSortDescriptor alloc] initWithKey:@"path" ascending:true]]];

  // listen for updates
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repositoryUpdatedNotification:) name:PBGitRepositoryEventNotification object:repository];

	[cachedFilesController setAutomaticallyRearrangesObjects:NO];
	[unstagedFilesController setAutomaticallyRearrangesObjects:NO];

	[commitSplitView setHidden:YES];
	[self performSelector:@selector(restoreCommitSplitViewPositiion) withObject:nil afterDelay:0];
}

- (void) _repositoryUpdatedNotification:(NSNotification *)notification {
    PBGitRepositoryWatcherEventType eventType = [(NSNumber *)[[notification userInfo] objectForKey:kPBGitRepositoryEventTypeUserInfoKey] unsignedIntValue];
    if(eventType & (PBGitRepositoryWatcherEventTypeWorkingDirectory | PBGitRepositoryWatcherEventTypeIndex)){
      // refresh if the working directory or index is modified
      [self refresh:self];
    }
}

- (void)closeView
{
	[self saveCommitSplitViewPosition];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[webController closeView];
}

- (NSResponder *)firstResponder;
{
	return commitMessageView;
}

- (IBAction)signOff:(id)sender
{
	NSError *error = nil;
	GTConfiguration *config = [repository.gtRepo configurationWithError:&error];
	NSString* userName = [config stringForKey:@"user.name"];
	NSString* userEmail = [config stringForKey:@"user.email"];
	if (!(userName && userEmail))
		return [[repository windowController] showMessageSheet:@"User's name not set" infoText:@"Signing off a commit requires setting user.name and user.email in your git config"];
	NSString *SOBline = [NSString stringWithFormat:@"Signed-off-by: %@ <%@>",
				userName,
				userEmail];

	if([commitMessageView.string rangeOfString:SOBline].location == NSNotFound) {
		NSArray *selectedRanges = [commitMessageView selectedRanges];
		commitMessageView.string = [NSString stringWithFormat:@"%@\n\n%@",
				commitMessageView.string, SOBline];
		[commitMessageView setSelectedRanges: selectedRanges];
	}
}

- (void) refresh:(id) sender
{
	self.isBusy = YES;
	self.status = @"Refreshing index…";
	[index refresh];

	// Reload refs (in case HEAD changed)
	[repository reloadRefs];
}

- (void) updateView
{
	[self refresh:nil];
}

- (IBAction) commit:(id) sender
{
    [self commitWithVerification:YES];
}

- (IBAction) forceCommit:(id) sender
{
    [self commitWithVerification:NO];
}

- (void) commitWithVerification:(BOOL) doVerify
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[repository.gitURL.path stringByAppendingPathComponent:@"MERGE_HEAD"]]) {
		[[repository windowController] showMessageSheet:@"Cannot commit merges" infoText:@"GitX cannot commit merges yet. Please commit your changes from the command line."];
		return;
	}

	if ([[cachedFilesController arrangedObjects] count] == 0) {
		[[repository windowController] showMessageSheet:@"No changes to commit" infoText:@"You must first stage some changes before committing"];
		return;
	}		
	
	NSString *commitMessage = [commitMessageView string];
	if ([commitMessage length] < 3) {
		[[repository windowController] showMessageSheet:@"Commitmessage missing" infoText:@"Please enter a commit message before committing"];
		return;
	}

	[cachedFilesController setSelectionIndexes:[NSIndexSet indexSet]];
	[unstagedFilesController setSelectionIndexes:[NSIndexSet indexSet]];

	self.isBusy = YES;
	[commitMessageView setEditable:NO];

	[index commitWithMessage:commitMessage andVerify:doVerify];
}


# pragma mark PBGitIndex Notification handling
- (void)refreshFinished:(NSNotification *)notification
{
	self.isBusy = NO;
	self.status = @"Index refresh finished";
}

- (void)commitStatusUpdated:(NSNotification *)notification
{
	self.status = [[notification userInfo] objectForKey:@"description"];
}

- (void)commitFinished:(NSNotification *)notification
{
	[commitMessageView setEditable:YES];
	[commitMessageView setString:@""];
	[webController setStateMessage:notification.userInfo[@"description"]];
}	

- (void)commitFailed:(NSNotification *)notification
{
	self.isBusy = NO;
	NSString *reason = [[notification userInfo] objectForKey:@"description"];
	self.status = [@"Commit failed: " stringByAppendingString:reason];
	[commitMessageView setEditable:YES];
	[[repository windowController] showMessageSheet:@"Commit failed" infoText:reason];
}

- (void)commitHookFailed:(NSNotification *)notification
{
	self.isBusy = NO;
	NSString *reason = [[notification userInfo] objectForKey:@"description"];
	self.status = [@"Commit hook failed: " stringByAppendingString:reason];
	[commitMessageView setEditable:YES];
	[[repository windowController] showCommitHookFailedSheet:@"Commit hook failed" infoText:reason commitController:self];
}

- (void)amendCommit:(NSNotification *)notification
{
	// Replace commit message with the old one if it's less than 3 characters long.
	// This is just a random number.
	if ([[commitMessageView string] length] > 3)
		return;
	
	NSString *message = [[notification userInfo] objectForKey:@"message"];
	commitMessageView.string = message;
}

- (void)indexChanged:(NSNotification *)notification
{
	[cachedFilesController rearrangeObjects];
	[unstagedFilesController rearrangeObjects];
    if ([[cachedFilesController arrangedObjects] count]) {
        [commitButton setEnabled:YES];
    } else {
        [commitButton setEnabled:NO];
    }

}

- (void)indexOperationFailed:(NSNotification *)notification
{
	[[repository windowController] showMessageSheet:@"Index operation failed" infoText:[[notification userInfo] objectForKey:@"description"]];
}


#pragma mark NSSplitView delegate methods

#define kCommitSplitViewTopViewMin 150
#define kCommitSplitViewBottomViewMin 100

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == commitSplitView)
		return kCommitSplitViewTopViewMin;

	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == commitSplitView)
		return [splitView frame].size.height - [splitView dividerThickness] - kCommitSplitViewBottomViewMin;

	return proposedMax;
}

// while the user resizes the window keep the lower (changes/message) view constant and just resize the upper view
// unless the upper view gets too small
- (void)resizeCommitSplitView
{
	NSRect newFrame = [commitSplitView frame];

	float dividerThickness = [commitSplitView dividerThickness];

	NSView *upperView = [[commitSplitView subviews] objectAtIndex:0];
	NSRect upperFrame = [upperView frame];
	upperFrame.size.width = newFrame.size.width;

	NSView *lowerView = [[commitSplitView subviews] objectAtIndex:1];
	NSRect lowerFrame = [lowerView frame];
	lowerFrame.size.width = newFrame.size.width;

	upperFrame.size.height = newFrame.size.height - lowerFrame.size.height - dividerThickness;
	if (upperFrame.size.height < kCommitSplitViewTopViewMin)
		upperFrame.size.height = kCommitSplitViewTopViewMin;

	lowerFrame.size.height = newFrame.size.height - upperFrame.size.height - dividerThickness;
	lowerFrame.origin.y = newFrame.size.height - lowerFrame.size.height;

	[upperView setFrame:upperFrame];
	[lowerView setFrame:lowerFrame];
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (splitView == commitSplitView)
		[self resizeCommitSplitView];
}

// NSSplitView does not save and restore the position of the splitView correctly so do it manually
- (void)saveCommitSplitViewPosition
{
	float position = [[[commitSplitView subviews] objectAtIndex:0] frame].size.height;
	[[NSUserDefaults standardUserDefaults] setFloat:position forKey:kCommitSplitViewPositionDefault];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// make sure this happens after awakeFromNib
- (void)restoreCommitSplitViewPositiion
{
	float position = [[NSUserDefaults standardUserDefaults] floatForKey:kCommitSplitViewPositionDefault];
	if (position < 1.0)
		position = [commitSplitView frame].size.height - 225;

	[commitSplitView setPosition:position ofDividerAtIndex:0];
	[commitSplitView setHidden:NO];
}

@end
