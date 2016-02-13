//
//  PBDetailController.m
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitWindowController.h"
#import "PBGitHistoryController.h"
#import "PBGitCommitController.h"
#import "Terminal.h"
#import "PBCommitHookFailedSheet.h"
#import "PBGitXMessageSheet.h"
#import "PBGitSidebarController.h"
#import "RJModalRepoSheet.h"

@interface PBGitWindowController ()

@property (nonatomic, strong) RJModalRepoSheet* currentModalSheet;

@end

@implementation PBGitWindowController

@synthesize repository;
@synthesize currentModalSheet;

- (id)initWithRepository:(PBGitRepository*)theRepository displayDefault:(BOOL)displayDefault
{
	if (!(self = [self initWithWindowNibName:@"RepositoryWindow"]))
		return nil;

	self.repository = theRepository;

	return self;
}

- (void)synchronizeWindowTitleWithDocumentName
{
    [super synchronizeWindowTitleWithDocumentName];

    // Point window proxy icon at project directory, not internal .git dir
    NSString *workingDirectory = [self.repository workingDirectory];
	if (workingDirectory)
	{
		[[self window] setRepresentedURL:[NSURL fileURLWithPath:workingDirectory
													isDirectory:YES]];
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
//	NSLog(@"Window will close!");

	if (sidebarController)
		[sidebarController closeView];

	if (contentController)
		[contentController removeObserver:self forKeyPath:@"status"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(showCommitView:)) {
		[menuItem setState:(contentController == sidebarController.commitViewController) ? YES : NO];
		return ![repository isBareRepository];
	} else if ([menuItem action] == @selector(showHistoryView:)) {
		[menuItem setState:(contentController != sidebarController.commitViewController) ? YES : NO];
		return ![repository isBareRepository];
	}
	return YES;
}

- (void) awakeFromNib
{
	[[self window] setDelegate:self];
	[[self window] setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
	[[self window] setContentBorderThickness:31.0f forEdge:NSMinYEdge];

	sidebarController = [[PBGitSidebarController alloc] initWithRepository:repository superController:self];
	[[sidebarController view] setFrame:[sourceSplitView bounds]];
	[sourceSplitView addSubview:[sidebarController view]];
	[sourceListControlsView addSubview:sidebarController.sourceListControlsView];

	[[statusField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	[progressIndicator setUsesThreadedAnimation:YES];

	NSImage *finderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kFinderIcon)];
	[finderItem setImage:finderImage];

	NSImage *terminalImage = [[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Utilities/Terminal.app/"];
	[terminalItem setImage:terminalImage];

	[self showWindow:nil];
}

- (void) removeAllContentSubViews
{
	if ([contentSplitView subviews])
		while ([[contentSplitView subviews] count] > 0)
			[[[contentSplitView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
}

- (void) changeContentController:(PBViewController *)controller
{
	if (!controller || (contentController == controller))
		return;

	if (contentController)
		[contentController removeObserver:self forKeyPath:@"status"];

	[self removeAllContentSubViews];

	contentController = controller;
	
	[[contentController view] setFrame:[contentSplitView bounds]];
	[contentSplitView addSubview:[contentController view]];

//	[self setNextResponder: contentController];
	[[self window] makeFirstResponder:[contentController firstResponder]];
	[contentController updateView];
	[contentController addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial context:@"statusChange"];
}

- (void) showCommitView:(id)sender
{
	[sidebarController selectStage];
}

- (void) showHistoryView:(id)sender
{
	[sidebarController selectCurrentBranch];
}

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller
{
	[PBCommitHookFailedSheet beginWithMessageText:messageText
										 infoText:infoText
								 commitController:controller];
}

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText
{
	[PBGitXMessageSheet beginMessageSheetForRepo:self.repository
								 withMessageText:messageText
										infoText:infoText];
}

- (void)showErrorSheet:(NSError *)error
{
	if ([[error domain] isEqualToString:PBGitRepositoryErrorDomain])
	{
		[PBGitXMessageSheet beginMessageSheetForRepo:self.repository withError:error];
	}
	else
	{
		[[NSAlert alertWithError:error] beginSheetModalForWindow:[self window]
												   modalDelegate:self
												  didEndSelector:nil
													 contextInfo:nil];
	}
}

- (void)showErrorSheetTitle:(NSString *)title message:(NSString *)message arguments:(NSArray *)arguments output:(NSString *)output
{
	NSString *command = [arguments componentsJoinedByString:@" "];
	NSString *reason = [NSString stringWithFormat:@"%@\n\ncommand: git %@\n%@", message, command, output];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  title, NSLocalizedDescriptionKey,
							  reason, NSLocalizedRecoverySuggestionErrorKey,
							  nil];
	NSError *error = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
	[self showErrorSheet:error];
}

- (IBAction) revealInFinder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[repository workingDirectory]];
}

- (IBAction) openInTerminal:(id)sender
{
	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier: @"com.apple.Terminal"];
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	NSString *cmd = [NSString stringWithFormat: @"cd \"%@\"; clear; echo '# Opened by GitX:'; git status", workingDirectory];
	[term doScript: cmd in: nil];
	[NSThread sleepForTimeInterval: 0.1];
	[term activate];
}

- (IBAction) refresh:(id)sender
{
	[contentController refresh:self];
}

- (void) updateStatus
{
	NSString *status = contentController.status;
	BOOL isBusy = contentController.isBusy;

	if (!status) {
		status = @"";
		isBusy = NO;
	}

	[statusField setStringValue:status];

	if (isBusy) {
		[progressIndicator startAnimation:self];
		[progressIndicator setHidden:NO];
	}
	else {
		[progressIndicator stopAnimation:self];
		[progressIndicator setHidden:YES];
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(__bridge NSString *)context isEqualToString:@"statusChange"]) {
		[self updateStatus];
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode
{
	[sidebarController setHistorySearch:searchString mode:mode];
}

- (void)showModalSheet:(RJModalRepoSheet *)sheet
{
	if (self.currentModalSheet == nil) {
		[NSApp beginSheet:[sheet window]
		   modalForWindow:self.window
			modalDelegate:sheet
		   didEndSelector:nil
			  contextInfo:NULL];
		self.currentModalSheet = sheet;
	}
}

- (void)hideModalSheet:(RJModalRepoSheet *)sheet
{
	if (self.currentModalSheet == sheet) {
		[NSApp endSheet:sheet.window];
		[sheet.window orderOut:sheet];
		self.currentModalSheet = nil;
	} else {
		assert(self.currentModalSheet == sheet);
	}
}

#pragma mark -
#pragma mark SplitView Delegates

#define kGitSplitViewMinWidth 150.0f
#define kGitSplitViewMaxWidth 300.0f

#pragma mark min/max widths while moving the divider

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	if (proposedMin < kGitSplitViewMinWidth)
		return kGitSplitViewMinWidth;

	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	if (dividerIndex == 0)
		return kGitSplitViewMaxWidth;

	return proposedMax;
}

#pragma mark constrain sidebar width while resizing the window

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame];

	float dividerThickness = [sender dividerThickness];

	NSView *sourceView = [[sender subviews] objectAtIndex:0];
	NSRect sourceFrame = [sourceView frame];
	sourceFrame.size.height = newFrame.size.height;

	NSView *mainView = [[sender subviews] objectAtIndex:1];
	NSRect mainFrame = [mainView frame];
	mainFrame.origin.x = sourceFrame.size.width + dividerThickness;
	mainFrame.size.width = newFrame.size.width - mainFrame.origin.x;
	mainFrame.size.height = newFrame.size.height;

	[sourceView setFrame:sourceFrame];
	[mainView setFrame:mainFrame];
}

@end
