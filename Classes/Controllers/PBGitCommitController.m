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
#import "PBGitRepositoryWatcher.h"
#import "PBCommitMessageView.h"
#import "NSSplitView+GitX.h"

#import <ObjectiveGit/GTRepository.h>
#import <ObjectiveGit/GTConfiguration.h>

#define kMinimalCommitMessageLength 3
#define kNotificationDictionaryDescriptionKey @"description"
#define kNotificationDictionaryMessageKey @"message"

#define FileChangesTableViewType @"GitFileChangedType"

@interface PBGitCommitController () <NSTextViewDelegate, NSMenuDelegate> {
	IBOutlet PBCommitMessageView *commitMessageView;

	IBOutlet NSArrayController *unstagedFilesController;
	IBOutlet NSArrayController *stagedFilesController;
	IBOutlet NSArrayController *trackedFilesController;

	IBOutlet NSTabView *controlsTabView;
	IBOutlet NSButton *commitButton;

	IBOutlet PBWebChangesController *webController;
	IBOutlet NSSplitView *commitSplitView;
}

@property (weak) IBOutlet NSTableView *unstagedTable;
@property (weak) IBOutlet NSTableView *stagedTable;

@end

@implementation PBGitCommitController

@synthesize stagedTable=stagedTable;
@synthesize unstagedTable=unstagedTable;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	if (!(self = [super initWithRepository:theRepository superController:controller]))
		return nil;

	PBGitIndex *index = theRepository.index;

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
	[commitSplitView pb_restoreAutosavedPositions];

	[super awakeFromNib];

	commitMessageView.repository = self.repository;
	commitMessageView.delegate = self;

	[commitMessageView setTypingAttributes:[NSDictionary dictionaryWithObject:[NSFont fontWithName:@"Menlo" size:12.0] forKey:NSFontAttributeName]];
	
	[unstagedFilesController setFilterPredicate:[NSPredicate predicateWithFormat:@"hasUnstagedChanges == 1"]];
	[stagedFilesController setFilterPredicate:[NSPredicate predicateWithFormat:@"hasStagedChanges == 1"]];
    [trackedFilesController setFilterPredicate:[NSPredicate predicateWithFormat:@"status > 0"]];
	
	[unstagedFilesController setSortDescriptors:[NSArray arrayWithObjects:
		[[NSSortDescriptor alloc] initWithKey:@"status" ascending:false],
		[[NSSortDescriptor alloc] initWithKey:@"path" ascending:true], nil]];
	[stagedFilesController setSortDescriptors:[NSArray arrayWithObject:
		[[NSSortDescriptor alloc] initWithKey:@"path" ascending:true]]];

    // listen for updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repositoryUpdatedNotification:) name:PBGitRepositoryEventNotification object:repository];

	[stagedFilesController setAutomaticallyRearrangesObjects:NO];
	[unstagedFilesController setAutomaticallyRearrangesObjects:NO];

	[unstagedTable setDoubleAction:@selector(didDoubleClickOnTable:)];
	[stagedTable setDoubleAction:@selector(didDoubleClickOnTable:)];

	[unstagedTable setTarget:self];
	[stagedTable setTarget:self];

	[unstagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];
	[stagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];

	// Copy the menu over so we have two discrete menu objects
	// which allows us to tell them apart in our delegate methods
	stagedTable.menu = [unstagedTable.menu copy];
}

- (void) _repositoryUpdatedNotification:(NSNotification *)notification {
    PBGitRepositoryWatcherEventType eventType = [(NSNumber *)[[notification userInfo] objectForKey:kPBGitRepositoryEventTypeUserInfoKey] unsignedIntValue];
    if(eventType & (PBGitRepositoryWatcherEventTypeWorkingDirectory | PBGitRepositoryWatcherEventTypeIndex)){
      // refresh if the working directory or index is modified
      [self refresh:self];
    }
}

- (void) updateView
{
	[self refresh:nil];
}

- (void)closeView
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[webController closeView];
}

- (NSResponder *)firstResponder;
{
	return commitMessageView;
}

- (PBGitIndex *) index {
	return repository.index;
}

- (void) commitWithVerification:(BOOL) doVerify
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[repository.gitURL.path stringByAppendingPathComponent:@"MERGE_HEAD"]]) {
		NSString * message = NSLocalizedString(@"Cannot commit merges",
											   @"Title for sheet that GitX cannot create merge commits");
		NSString * info = NSLocalizedString(@"GitX cannot commit merges yet. Please commit your changes from the command line.",
											@"Information text for sheet that GitX cannot create merge commits");

		[self.windowController showMessageSheet:message infoText:info];
		return;
	}

	if ([[stagedFilesController arrangedObjects] count] == 0) {
		NSString * message = NSLocalizedString(@"No changes to commit",
											   @"Title for sheet that you need to stage changes before creating a commit");
		NSString * info = NSLocalizedString(@"You need to stage some changed files before committing by moving them to the list of Staged Changes.",
											@"Information text for sheet that you need to stage changes before creating a commit");

		[self.windowController showMessageSheet:message infoText:info];
		return;
	}

	NSString *commitMessage = [commitMessageView string];
	if (commitMessage.length < kMinimalCommitMessageLength) {
		NSString * message = NSLocalizedString(@"Missing commit message",
											   @"Title for sheet that you need to enter a commit message before creating a commit");
		NSString * info = [NSString stringWithFormat:
						   NSLocalizedString(@"Please enter a commit message at least %i characters long before commiting.",
											 @"Format for sheet that you need to enter a commit message before creating a commit giving the minimum length of the commit message required"),
						   kMinimalCommitMessageLength ];
		[self.windowController showMessageSheet:message infoText:info ];
		return;
	}

	[stagedFilesController setSelectionIndexes:[NSIndexSet indexSet]];
	[unstagedFilesController setSelectionIndexes:[NSIndexSet indexSet]];

	self.isBusy = YES;
	commitMessageView.editable = NO;

	[repository.index commitWithMessage:commitMessage andVerify:doVerify];
}

- (void)discardChangesForFiles:(NSArray *)files force:(BOOL)force
{
	void (^performDiscard)(NSModalResponse) = ^(NSModalResponse returnCode) {
		if (returnCode != NSAlertFirstButtonReturn) return;

		[self.repository.index discardChangesForFiles:files];
	};

	if (!force) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"Discard changes", @"Title for Discard Changes sheet");
		alert.informativeText = NSLocalizedString(@"Are you sure you wish to discard the changes to this file?\n\nYou cannot undo this operation.", @"Informative text for Discard Changes sheet");

		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button in Discard Changes sheet")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button in Discard Changes sheet")];


		[alert beginSheetModalForWindow:self.windowController.window completionHandler:performDiscard];
	} else {
		performDiscard(NSAlertFirstButtonReturn);
	}
}

#pragma mark IBActions

- (IBAction)signOff:(id)sender
{
	NSError *error = nil;
	GTConfiguration *config = [repository.gtRepo configurationWithError:&error];
	NSString *userName = [config stringForKey:@"user.name"];
	NSString *userEmail = [config stringForKey:@"user.email"];
	if (!(userName && userEmail)) {
		return [self.windowController showMessageSheet:NSLocalizedString(@"User‘s name not set",
																		 @"Title for sheet that the user’s name is not set in the git configuration")
											  infoText:NSLocalizedString(@"Signing off a commit requires setting user.name and user.email in your git config",
																		 @"Information text for sheet that the user’s name is not set in the git configuration")];
	}

	NSString *SOBline = [NSString stringWithFormat:NSLocalizedString(@"Signed-off-by: %@ <%@>",
																	 @"Signed off message format. Most likely this should not be localised."),
						 userName,
						 userEmail];

	if([commitMessageView.string rangeOfString:SOBline].location == NSNotFound) {
		NSArray *selectedRanges = [commitMessageView selectedRanges];
		commitMessageView.string = [NSString stringWithFormat:@"%@\n\n%@", commitMessageView.string, SOBline];
		[commitMessageView setSelectedRanges:selectedRanges];
	}
}

- (IBAction) refresh:(id) sender
{
	self.isBusy = YES;
	self.status = NSLocalizedString(@"Refreshing index…", @"Message in status bar while the index is refreshing");
	[repository.index refresh];

	// Reload refs (in case HEAD changed)
	[repository reloadRefs];
}

- (IBAction) commit:(id) sender
{
    [self commitWithVerification:YES];
}

- (IBAction) forceCommit:(id) sender
{
    [self commitWithVerification:NO];
}

- (IBAction)toggleAmendCommit:(id)sender
{
	[[[self repository] index] setAmend:![[[self repository] index] isAmend]];
}

- (NSArray <PBChangedFile *> *)selectedFilesForSender:(id)sender
{
	NSParameterAssert(sender != nil);

	if (![sender isKindOfClass:[NSMenuItem class]]) return nil;

	NSTableView *table = (sender == stagedTable.menu ? stagedTable : unstagedTable);
	NSArrayController *controller = (table.tag == 0 ? unstagedFilesController : stagedFilesController);
	return controller.selectedObjects;
}

- (IBAction)openFiles:(id)sender
{
	NSArray <PBChangedFile *> *selectedFiles = [self selectedFilesForSender:sender];

	NSMutableArray <NSURL *> *fileURLs = [NSMutableArray array];
	NSURL *workingDirectoryURL = self.repository.workingDirectoryURL;
	for (PBChangedFile *file in selectedFiles) {
		[fileURLs addObject:[workingDirectoryURL URLByAppendingPathComponent:file.path]];
	}
	[self.windowController openURLs:fileURLs];
}

- (IBAction)revealInFinder:(id)sender
{
	NSArray <PBChangedFile *> *selectedFiles = [self selectedFilesForSender:sender];

	NSMutableArray <NSURL *> *fileURLs = [NSMutableArray array];
	NSURL *workingDirectoryURL = self.repository.workingDirectoryURL;
	for (PBChangedFile *file in selectedFiles) {
		[fileURLs addObject:[workingDirectoryURL URLByAppendingPathComponent:file.path]];
	}
	[self.windowController revealURLsInFinder:fileURLs];
}

- (IBAction)moveToTrash:(id)sender
{
	NSArray <PBChangedFile *> *selectedFiles = [self selectedFilesForSender:sender];

	NSURL *workingDirectoryURL = self.repository.workingDirectoryURL;

	NSAlert *confirmTrash = [[NSAlert alloc] init];
	confirmTrash.alertStyle = NSAlertStyleWarning;
	confirmTrash.messageText = NSLocalizedString(@"Move to trash", @"Move to trash alert - title");
	confirmTrash.informativeText = NSLocalizedString(@"Do you want to move the following files to the trash ?", @"Move to trash alert - message");
	[confirmTrash addButtonWithTitle:NSLocalizedString(@"OK", @"Move to trash alert - OK button")];
	[confirmTrash addButtonWithTitle:NSLocalizedString(@"Cancel", @"Move to trash alert - Cancel button")];

	[confirmTrash beginSheetModalForWindow:self.windowController.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSAlertFirstButtonReturn) return;

		BOOL anyTrashed = NO;
		for (PBChangedFile *file in selectedFiles)
		{
			NSURL* fileURL = [workingDirectoryURL URLByAppendingPathComponent:[file path]];

			NSError* error = nil;
			NSURL* resultURL = nil;
			if ([[NSFileManager defaultManager] trashItemAtURL:fileURL
											  resultingItemURL:&resultURL
														 error:&error])
			{
				anyTrashed = YES;
			}
		}
		if (anyTrashed)
		{
			[self.repository.index refresh];
		}
	}];
}

- (IBAction)ignoreFiles:(id) sender
{
	NSArray <PBChangedFile *> *selectedFiles = [self selectedFilesForSender:sender];
	if ([selectedFiles count] == 0)
		return;

	// Build selected files
	NSMutableArray *fileList = [NSMutableArray array];
	for (PBChangedFile *file in selectedFiles) {
		NSString *name = file.path;
		if ([name length] > 0)
			[fileList addObject:name];
	}

	NSError *error = nil;
	BOOL success = [self.repository ignoreFilePaths:fileList error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
	[self.repository.index refresh];
}

static void reselectNextFile(NSArrayController *controller)
{
	NSUInteger currentSelectionIndex = controller.selectionIndex;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSUInteger newSelectionIndex = MIN(currentSelectionIndex, [controller.arrangedObjects count] - 1);
		controller.selectionIndex = newSelectionIndex;
	});
}

- (IBAction)stageFiles:(id)sender {
	[self.repository.index stageFiles:unstagedFilesController.selectedObjects];
	reselectNextFile(unstagedFilesController);
}

- (IBAction)unstageFiles:(id)sender {
	[self.repository.index unstageFiles:stagedFilesController.selectedObjects];
	reselectNextFile(stagedFilesController);
}

- (IBAction)discardFiles:(id)sender
{
	NSArray *selectedFiles = unstagedFilesController.selectedObjects;
	if ([selectedFiles count] > 0)
		[self discardChangesForFiles:selectedFiles force:FALSE];
}

- (IBAction)discardFilesForcibly:(id)sender
{
	NSArray *selectedFiles = unstagedFilesController.selectedObjects;
	if ([selectedFiles count] > 0)
		[self discardChangesForFiles:selectedFiles force:TRUE];
}

# pragma mark PBGitIndex Notification handling

- (void)refreshFinished:(NSNotification *)notification
{
	self.isBusy = NO;
	self.status = NSLocalizedString(@"Index refresh finished", @"Message in status bar when refreshing the index is done");
}

- (void)commitStatusUpdated:(NSNotification *)notification
{
	self.status = notification.userInfo[kNotificationDictionaryDescriptionKey];
}

- (void)commitFinished:(NSNotification *)notification
{
	commitMessageView.editable = YES;
	commitMessageView.string = @"";
	[webController setStateMessage:notification.userInfo[kNotificationDictionaryDescriptionKey]];
}	

- (void)commitFailed:(NSNotification *)notification
{
	self.isBusy = NO;
	commitMessageView.editable = YES;

	NSString *reason = notification.userInfo[kNotificationDictionaryDescriptionKey];
	self.status = [NSString stringWithFormat:
				   NSLocalizedString(@"Commit failed: %@",
									 @"Message in status bar when creating a commit has failed, including the reason for the failure"),
				   reason];
	[self.windowController showMessageSheet:NSLocalizedString(@"Commit failed", @"Title for sheet that creating a commit has failed")
										 infoText:reason];
}

- (void)commitHookFailed:(NSNotification *)notification
{
	self.isBusy = NO;
	commitMessageView.editable = YES;

	NSString *reason = notification.userInfo[kNotificationDictionaryDescriptionKey];
	self.status = [NSString stringWithFormat:
				   NSLocalizedString(@"Commit hook failed: %@",
									 @"Message in status bar when running a commit hook failed, including the reason for the failure"),
				   reason];
	[self.windowController showCommitHookFailedSheet:NSLocalizedString(@"Commit hook failed", @"Title for sheet that running a commit hook has failed")
												  infoText:reason
										  commitController:self];
}

- (void)amendCommit:(NSNotification *)notification
{
	// Replace commit message with the old one if it's less than 3 characters long.
	// This is just a random number.
	if ([[commitMessageView string] length] > kMinimalCommitMessageLength) {
		return;
	}
	
	NSString *message = notification.userInfo[kNotificationDictionaryMessageKey];
	commitMessageView.string = message;
}

- (void)indexChanged:(NSNotification *)notification
{
	[stagedFilesController rearrangeObjects];
	[unstagedFilesController rearrangeObjects];
    
    commitButton.enabled = ([[stagedFilesController arrangedObjects] count] > 0);
}

- (void)indexOperationFailed:(NSNotification *)notification
{
	[self.windowController showMessageSheet:NSLocalizedString(@"Index operation failed", @"Title for sheet that running an index operation has failed")
										 infoText:notification.userInfo[kNotificationDictionaryDescriptionKey]];
}

#pragma mark NSTextView delegate methods

- (void)focusTable:(NSTableView *)table
{
    if ([table numberOfRows] > 0) {
        if ([table numberOfSelectedRows] == 0) {
            [table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        }
        [[table window] makeFirstResponder:table];
    }
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
{
    if (commandSelector == @selector(insertTab:)) {
        [self focusTable:stagedTable];
        return YES;
    } else if (commandSelector == @selector(insertBacktab:)) {
        [self focusTable:unstagedTable];
        return YES;
	}
    return NO;
}

#pragma mark NSMenu delegate

NSString *PBLocalizedStringForArray(NSArray<PBChangedFile *> *array, NSString *singleFormat, NSString *multipleFormat, NSString *defaultString)
{
	if (array.count == 0) {
		return defaultString;
	}
	else if (array.count == 1) {
		return [NSString stringWithFormat:singleFormat, array.firstObject.path.lastPathComponent];
	}
	return [NSString stringWithFormat:multipleFormat, array.count];
}

BOOL canDiscardAnyFileIn(NSArray<PBChangedFile *> *files)
{
	for (PBChangedFile *file in files)
	{
		if (file.hasUnstagedChanges)
		{
			return YES;
		}
	}
	return NO;
}

BOOL shouldTrashInsteadOfDiscardAnyFileIn(NSArray <PBChangedFile *> *files)
{
	for (PBChangedFile *file in files)
	{
		if (file.status != NEW)
		{
			return NO;
		}
	}
	return YES;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	for (NSMenuItem *item in menu.itemArray) {
		[self validateMenuItem:item];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	NSTableView *table = (menuItem.menu == stagedTable.menu ? stagedTable : unstagedTable);
	NSArray <PBChangedFile *> *filesForStaging = unstagedFilesController.selectedObjects;
	NSArray <PBChangedFile *> *filesForUnstaging = stagedFilesController.selectedObjects;
	NSArray <PBChangedFile *> *selectedFiles = (table.tag == 0 ? filesForStaging : filesForUnstaging);
	BOOL isInContextualMenu = (menuItem.parentItem == nil);

	if (menuItem.action == @selector(stageFiles:)) {
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(filesForStaging,
													   NSLocalizedString(@"Stage “%@”", @"Stage file menu item (single file with name)"),
													   NSLocalizedString(@"Stage %i Files", @"Stage file menu item (multiple files with number)"),
													   NSLocalizedString(@"Stage", @"Stage file menu item (empty selection)"));

			menuItem.hidden = (filesForStaging.count == 0);
		}
		return filesForStaging.count > 0;
	}
	else if (menuItem.action == @selector(unstageFiles:)) {
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(filesForUnstaging,
													   NSLocalizedString(@"Unstage “%@”", @"Unstage file menu item (single file with name)"),
													   NSLocalizedString(@"Unstage %i Files", @"Unstage file menu item (multiple files with number)"),
													   NSLocalizedString(@"Unstage", @"Unstage file menu item (empty selection)"));

			menuItem.hidden = (filesForUnstaging.count == 0);
		}
		return filesForUnstaging.count > 0;
	}
	else if (menuItem.action == @selector(discardFiles:)) {
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(filesForStaging,
													   NSLocalizedString(@"Discard changes to “%@”…", @"Discard changes menu item (single file with name)"),
													   NSLocalizedString(@"Discard changes to %i Files…", @"Discard changes menu item (multiple files with number)"),
													   NSLocalizedString(@"Discard…", @"Discard changes menu item (empty selection)"));

			menuItem.hidden = shouldTrashInsteadOfDiscardAnyFileIn(filesForStaging);
		}
		return filesForStaging.count > 0 && canDiscardAnyFileIn(filesForStaging);
	}
	else if (menuItem.action == @selector(discardFilesForcibly:)) {
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(filesForStaging,
													   NSLocalizedString(@"Discard changes to “%@”", @"Force Discard changes menu item (single file with name)"),
													   NSLocalizedString(@"Discard changes to  %i Files", @"Force Discard changes menu item (multiple files with number)"),
													   NSLocalizedString(@"Discard", @"Force Discard changes menu item (empty selection)"));
			BOOL shouldHide = shouldTrashInsteadOfDiscardAnyFileIn(filesForStaging);
			menuItem.hidden = shouldHide;
			// NSMenu does not seem to hide alternative items properly: only activate the alternative seeing when menu item is shown.
			menuItem.alternate = !shouldHide;
		}
		return filesForStaging.count > 0 && canDiscardAnyFileIn(filesForStaging);
	}
	else if (menuItem.action == @selector(trashFiles:)) {
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(filesForStaging,
													   NSLocalizedString(@"Move “%@” to Trash", @"Move to Trash menu item (single file with name)"),
													   NSLocalizedString(@"Move %i Files to Trash", @"Move to Trash menu item (multiple files with number)"),
													   NSLocalizedString(@"Move to Trash", @"Move to Trash menu item (empty selection)"));
			BOOL isVisible = shouldTrashInsteadOfDiscardAnyFileIn(filesForStaging) && table.tag != 1;
			menuItem.hidden = !isVisible;
		}
		return filesForStaging.count > 0 && canDiscardAnyFileIn(filesForStaging);
	}
	else if (menuItem.action == @selector(openFiles:)) {
		if (selectedFiles.count == 0) return NO;

		NSString *filePath = selectedFiles.firstObject.path;
		if (isInContextualMenu) {
			if (selectedFiles.count == 1 && [self.repository submoduleAtPath:filePath error:NULL] != nil) {
				menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Open Submodule “%@” in GitX", @"Open Submodule Repository in GitX menu item (single file with name)"),
								  filePath.stringByStandardizingPath];
			} else {
				menuItem.title = PBLocalizedStringForArray(selectedFiles,
														   NSLocalizedString(@"Open “%@”", @"Open File menu item (single file with name)"),
														   NSLocalizedString(@"Open %i Files", @"Open File menu item (multiple files with number)"),
														   NSLocalizedString(@"Open", @"Open File menu item (empty selection)"));
			}
		}
		return YES;
	}
	else if (menuItem.action == @selector(ignoreFiles:)) {
		BOOL isActive = selectedFiles.count > 0 && table.tag == 0;
		if (isInContextualMenu) {
			menuItem.title = PBLocalizedStringForArray(selectedFiles,
													   NSLocalizedString(@"Ignore “%@”", @"Ignore File menu item (single file with name)"),
													   NSLocalizedString(@"Ignore %i Files", @"Ignore File menu item (multiple files with number)"),
													   NSLocalizedString(@"Ignore", @"Ignore File menu item (empty selection)"));
			menuItem.hidden = !isActive;
		}
		return isActive;
	}
	else if (menuItem.action == @selector(revealInFinder:)) {
		BOOL active = selectedFiles.count == 1;
		if (isInContextualMenu) {
			if (active) {
				menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Reveal “%@” in Finder", @"Reveal File in Finder contextual menu item (single file with name)"),
								  selectedFiles.firstObject.path.lastPathComponent];
			} else {
				menuItem.title = NSLocalizedString(@"Reveal in Finder", @"Reveal File in Finder contextual menu item (empty selection)");
			}
			menuItem.hidden = !active;
		}
		return active;
	}
	else if (menuItem.action == @selector(toggleAmendCommit:)) {
		menuItem.state = [[[self repository] index] isAmend] ? NSOnState : NSOffState;
		return YES;
	}

	return menuItem.enabled;
}

#pragma mark PBFileChangedTableView delegate

- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
	id controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;
	[[tableColumn dataCell] setImage:[[[controller arrangedObjects] objectAtIndex:rowIndex] icon]];
}

- (void) didDoubleClickOnTable:(NSTableView *) tableView
{
	NSArrayController *controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;

	NSIndexSet *selectionIndexes = [tableView selectedRowIndexes];
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:selectionIndexes];
	if ([tableView tag] == 0) {
		[self.index stageFiles:files];
	}
	else {
		[self.index unstageFiles:files];
	}
}

- (BOOL) tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	// Copy the row numbers to the pasteboard.
	[pboard declareTypes:[NSArray arrayWithObjects:FileChangesTableViewType, NSFilenamesPboardType, nil] owner:self];

	// Internal, for dragging from one tableview to the other
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	[pboard setData:data forType:FileChangesTableViewType];

	// External, to drag them to for example XCode or Textmate
	NSArrayController *controller = [tv tag] == 0 ? unstagedFilesController : stagedFilesController;
	NSArray *files = [controller.arrangedObjects objectsAtIndexes:rowIndexes];
	NSURL *workingDirectoryURL = self.repository.workingDirectoryURL;

	NSMutableArray<NSURL *> *URLs = [NSMutableArray arrayWithCapacity:rowIndexes.count];
	for (PBChangedFile *file in files) {
		[URLs addObject:[workingDirectoryURL URLByAppendingPathComponent:file.path]];
	}
	[pboard writeObjects:URLs];

	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if ([info draggingSource] == tableView)
		return NSDragOperationNone;

	[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard* pboard = [info draggingPasteboard];
	NSData* rowData = [pboard dataForType:FileChangesTableViewType];
	NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

	NSArrayController *controller = [aTableView tag] == 0 ? stagedFilesController : unstagedFilesController;
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:rowIndexes];

	if ([aTableView tag] == 0) {
		[self.index unstageFiles:files];
	}
	else {
		[self.index stageFiles:files];
	}

	return YES;
}

@end
