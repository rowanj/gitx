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
#import "PBTerminalUtil.h"
#import "PBCommitHookFailedSheet.h"
#import "PBGitXMessageSheet.h"
#import "PBGitSidebarController.h"
#import "PBAddRemoteSheet.h"
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBGitDefaults.h"
#import "PBSourceViewItem.h"
#import "PBGitRevSpecifier.h"
#import "PBGitRef.h"
#import "PBError.h"
#import "PBRepositoryDocumentController.h"
#import "PBRefMenuItem.h"
#import "PBRemoteProgressSheet.h"

@implementation PBGitWindowController

@synthesize repository;

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

	if ([self isWindowLoaded]) {
		// Point window proxy icon at project directory, not internal .git dir
		[[self window] setRepresentedURL:self.repository.workingDirectoryURL];
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
	} else if (menuItem.action == @selector(fetchRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Fetch “%@”" plainTitle:@"Fetch"];
	} else if (menuItem.action == @selector(pullRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Pull From “%@”" plainTitle:@"Pull"];
	} else if (menuItem.action == @selector(pullRebaseRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Pull From “%@” and Rebase" plainTitle:@"Pull and Rebase"];
	}
	
	return YES;
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem remoteTitle:(NSString *)localisationKeyWithRemote plainTitle:(NSString *)localizationKeyWithoutRemote
{
	PBSourceViewItem *item = [self selectedItem];
	PBGitRef *ref = item.ref;

	if (!ref && (item.parent == sidebarController.remotes)) {
		ref = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:item.title]];
	}
	
	if (ref.isRemote) {
		menuItem.title = [NSString stringWithFormat:NSLocalizedString(localisationKeyWithRemote, @""), ref.remoteName];
		return YES;
	}

	menuItem.title = NSLocalizedString(localizationKeyWithoutRemote, @"");
	return NO;
}


- (void) windowDidLoad
{
	[super windowDidLoad];

	// Explicitly set the frame using the autosave name
	// Opening the first and second documents works fine, but the third and subsequent windows aren't positioned correctly
	[[self window] setFrameUsingName:@"GitX"];
	[[self window] setRepresentedURL:self.repository.workingDirectoryURL];

	sidebarController = [[PBGitSidebarController alloc] initWithRepository:repository superController:self];
	[[sidebarController view] setFrame:[sourceSplitView bounds]];
	[sourceSplitView addSubview:[sidebarController view]];
	[sourceListControlsView addSubview:sidebarController.sourceListControlsView];

	[[statusField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	[progressIndicator setUsesThreadedAnimation:YES];
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
								 commitController:controller
	 completionHandler:^(id  _Nonnull sheet, NSModalResponse returnCode) {
		 if (returnCode != NSModalResponseOK) return;

		 [sidebarController.commitViewController forceCommit:self];
	 }];
}

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText
{
	[PBGitXMessageSheet beginSheetWithMessage:messageText info:infoText windowController:self];
}

- (void)showErrorSheet:(NSError *)error
{
	if ([[error domain] isEqualToString:PBGitXErrorDomain])
	{
		[PBGitXMessageSheet beginSheetWithError:error windowController:self];
	}
	else
	{
		[[NSAlert alertWithError:error] beginSheetModalForWindow:[self window]
												   modalDelegate:self
												  didEndSelector:nil
													 contextInfo:nil];
	}
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

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode
{
	[sidebarController setHistorySearch:searchString mode:mode];
}



- (void)openURLs:(NSArray <NSURL *> *)fileURLs
{
	if (fileURLs.count == 0) return;

	NSMutableArray *nonSubmoduleURLs = [NSMutableArray array];

	for (NSURL *fileURL in fileURLs) {
		GTSubmodule *submodule = [self.repository submoduleAtPath:fileURL.path error:NULL];
		if (!submodule) {
			[nonSubmoduleURLs addObject:fileURL];
		} else {
			NSURL *submoduleURL = [submodule.parentRepository.fileURL URLByAppendingPathComponent:submodule.path isDirectory:YES];
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:submoduleURL
																				   display:YES
																		 completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
																			 // Do nothing on completion.
																			 return;
																		 }];
		}
	}

	[[NSWorkspace sharedWorkspace] openURLs:nonSubmoduleURLs
					withAppBundleIdentifier:nil
									options:0
			 additionalEventParamDescriptor:nil
						  launchIdentifiers:NULL];
}

- (void)revealURLsInFinder:(NSArray <NSURL *> *)fileURLs
{
	if (fileURLs.count == 0) return;

	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

#pragma mark IBActions

- (IBAction) showAddRemoteSheet:(id)sender
{
	[self addRemote:sender];
}

- (IBAction)addRemote:(id)sender
{
	[PBAddRemoteSheet beginSheetWithWindowController:self completionHandler:^(PBAddRemoteSheet *addSheet, NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) return;

		NSString *remoteName = addSheet.remoteName.stringValue;
		NSString *remoteURL = addSheet.remoteURL.stringValue;

		NSString *description = [NSString stringWithFormat:@"Adding remote \"%@\"", remoteName];

		PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Adding remote"
																				 description:description
																			windowController:self];
		[progressSheet beginProgressSheetForBlock:^{
			NSError *error = nil;
			BOOL success = [repository addRemote:remoteName withURL:remoteURL error:&error];
			return success ? nil : error;
		} completionHandler:^(NSError *error) {
			if (error) {
				[self showErrorSheet:error];
				return;
			}

			// Now fetch that remote
			PBGitRef *remoteRef = [repository refForName:remoteName];
			[self performFetchForRef:remoteRef];
		}];
	}];
}

- (void)performFetchForRef:(PBGitRef *)ref
{
	NSString *remoteName = (ref ? ref.remoteName : @"all remotes");
	NSString *description = [NSString stringWithFormat:@"Fetching tracking branches for %@", remoteName];

	PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Fetching remote…"
																			 description:description
																		windowController:self];

	[progressSheet beginProgressSheetForBlock:^{
		NSError *error = nil;
		BOOL success = [repository fetchRemoteForRef:ref error:&error];
		return (success ? nil : error);
	} completionHandler:^(NSError *error) {
		if (error) {
			[self showErrorSheet:error];
		}
	}];
}

- (IBAction) fetchRemote:(id)sender {
	PBGitRef *ref = [self selectedItem].ref;
	[self performFetchForRef:ref];
}

- (IBAction) fetchAllRemotes:(id)sender {
	[self performFetchForRef:nil];
}

- (void)performPullForBranch:(PBGitRef *)branchRef remote:(PBGitRef *)remoteRef rebase:(BOOL)rebase {
	NSString *description = nil;
	if (!branchRef && !remoteRef) {
		NSAssert(NO, @"Asked to pull no branch from no remote");
	} else if (!branchRef) {
		description = [NSString stringWithFormat:@"Pulling all tracking branches from %@", remoteRef.remoteName];
	} else if (!remoteRef) {
		description = [NSString stringWithFormat:@"Pulling default remote for branch %@", branchRef.shortName];
	} else {
		description = [NSString stringWithFormat:@"Pulling branch %@ from remote %@", branchRef.shortName, remoteRef.remoteName];
	}

	PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Pulling remote…"
																			 description:description
																		windowController:self];

	[progressSheet beginProgressSheetForBlock:^{
		NSError *error = nil;
		BOOL success = [repository pullBranch:branchRef fromRemote:remoteRef rebase:rebase error:&error];
		return success ? nil : error;
	} completionHandler:^(NSError *error) {
		if (error) {
			[self showErrorSheet:error];
		}
	}];
}

- (IBAction) pullRemote:(id)sender {
	PBGitRef *ref = [self selectedItem].revSpecifier.ref;
	[self performPullForBranch:ref remote:nil rebase:NO];
}

- (IBAction) pullRebaseRemote:(id)sender {
	PBGitRef *ref = [self selectedItem].revSpecifier.ref;
	[self performPullForBranch:ref remote:nil rebase:YES];
}

- (IBAction) pullDefaultRemote:(id)sender {
	PBGitRef *ref = [self selectedItem].revSpecifier.ref;
	[self performPullForBranch:ref remote:nil rebase:NO];
}

- (IBAction) pullRebaseDefaultRemote:(id)sender {
	PBGitRef *ref = [self selectedItem].revSpecifier.ref;
	[self performPullForBranch:ref remote:nil rebase:YES];
}

- (void)performPushForBranch:(PBGitRef *)branchRef toRemote:(PBGitRef *)remoteRef
{
	if ((!branchRef && !remoteRef)
		|| (branchRef && !branchRef.isBranch && !branchRef.isRemoteBranch && !branchRef.isTag)
		|| (remoteRef && !remoteRef.isRemote))
		return;

	// This block is actually responsible for performing the push operation
	void (^pushBlock)(void) = ^{
		NSString *description = nil;
		if (branchRef && remoteRef)
			description = [NSString stringWithFormat:@"Pushing %@ '%@' to remote %@", branchRef.refishType, branchRef.shortName, remoteRef.remoteName];
		else if (branchRef)
			description = [NSString stringWithFormat:@"Pushing %@ '%@' to default remote", branchRef.refishType, branchRef.shortName];
		else
			description = [NSString stringWithFormat:@"Pushing updates to remote %@", remoteRef.remoteName];

		PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Pushing remote…"
																				 description:description
																			windowController:self];

		[progressSheet beginProgressSheetForBlock:^{
			NSError *error = nil;
			BOOL success = [repository pushBranch:branchRef toRemote:remoteRef error:&error];
			return (success ? nil : error);
		} completionHandler:^(NSError *error) {
			if (error) {
				[self showErrorSheet:error];
			}
		}];
	};

	if ([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogConfirmPush]) {
		pushBlock();
		return;
	}

	NSString *description = nil;
	if (branchRef && remoteRef)
		description = [NSString stringWithFormat:@"Push %@ '%@' to remote %@", branchRef.refishType, branchRef.shortName, remoteRef.remoteName];
	else if (branchRef)
		description = [NSString stringWithFormat:@"Push %@ '%@' to default remote", branchRef.refishType, branchRef.shortName];
	else
		description = [NSString stringWithFormat:@"Push updates to remote %@", remoteRef.remoteName];

	NSString *sdesc = [NSString stringWithFormat:@"p%@", [description substringFromIndex:1]];
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = description;
	alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to %@?", sdesc];
	[alert addButtonWithTitle:@"Push"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setShowsSuppressionButton:YES];

	[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		if ([alert.suppressionButton state] == NSOnState)
			[PBGitDefaults suppressDialogWarningForDialog:kDialogConfirmPush];

		if (returnCode != NSAlertFirstButtonReturn) return;

		pushBlock();
	}];
}

- (PBSourceViewItem *) selectedItem {
	NSOutlineView *sourceView = sidebarController.sourceView;
	return [sourceView itemAtRow:sourceView.selectedRow];
}

- (IBAction) stashSave:(id) sender
{
	NSError *error = nil;
	BOOL success = [repository stashSaveWithKeepIndex:NO error:&error];

	if (!success) [self showErrorSheet:error];
}

- (IBAction) stashSaveWithKeepIndex:(id) sender
{
	NSError *error = nil;
	BOOL success = [repository stashSaveWithKeepIndex:YES error:&error];

	if (!success) [self showErrorSheet:error];
}

- (IBAction) stashPop:(id) sender
{
	if ([repository.stashes count] <= 0) return;

	PBGitStash * latestStash = [repository.stashes objectAtIndex:0];
	NSError *error = nil;
	BOOL success = [repository stashPop:latestStash error:&error];

	if (!success) [self showErrorSheet:error];
}


- (NSArray <NSURL *> *)selectedURLsFromSender:(id)sender {
	NSArray *selectedFiles = [sender representedObject];
	if (![selectedFiles isKindOfClass:[NSArray class]] || [selectedFiles count] == 0)
		return nil;

	NSMutableArray *URLs = [NSMutableArray array];
	for (id file in selectedFiles) {
		NSString *path = file;
		// Those can be PBChangedFiles sent by PBGitIndexController. Get their path.
		if ([file respondsToSelector:@selector(path)]) {
			path = [file path];
		}

		if (![path isKindOfClass:[NSString class]])
			continue;
		[URLs addObject:[self.repository.workingDirectoryURL URLByAppendingPathComponent:path]];
	}

	return URLs;
}

- (IBAction) openFiles:(id)sender {
	NSArray <NSURL *> *fileURLs = [self selectedURLsFromSender:sender];
	[self openURLs:fileURLs];
}

- (IBAction) revealInFinder:(id)sender
{
	[self revealURLsInFinder:@[self.repository.workingDirectoryURL]];
}

- (IBAction) openInTerminal:(id)sender
{
	[PBTerminalUtil runCommand:@"git status" inDirectory:self.repository.workingDirectoryURL];
}

- (IBAction) refresh:(id)sender
{
	[contentController refresh:self];
}

- (void) createBranch:(id)sender
{
	PBGitRef *currentRef = [repository.currentBranch ref];

	id <PBGitRefish> refish = nil;
	if ([sender isKindOfClass:[PBRefMenuItem class]]) {
		refish = [[(PBRefMenuItem *)sender refishs] firstObject];
	} else {
		PBGitCommit *selectedCommit = sidebarController.historyViewController.selectedCommits.firstObject;
		if (!selectedCommit || [selectedCommit hasRef:currentRef]) {
			refish = currentRef;
		} else {
			refish = selectedCommit;
		}
	}

	[PBCreateBranchSheet beginSheetWithRefish:refish windowController:self completionHandler:^(PBCreateBranchSheet *sheet, NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) return;

		NSError *error = nil;
		BOOL success = [self.repository createBranch:[sheet.branchNameField stringValue] atRefish:sheet.startRefish error:&error];
		if (!success) {
			[self showErrorSheet:error];
			return;
		}

		[PBGitDefaults setShouldCheckoutBranch:sheet.shouldCheckoutBranch];

		if (sheet.shouldCheckoutBranch) {
			success = [self.repository checkoutRefish:sheet.selectedRef error:&error];
			if (!success) {
				[self showErrorSheet:error];
				return;
			}
		}
	}];
}

- (void) createTag:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = nil;
	if ([sender isKindOfClass:[PBRefMenuItem class]]) {
		refish = [sender refishs].firstObject;
	} else {
		PBGitCommit *selectedCommit = sidebarController.historyViewController.selectedCommits.firstObject;
		if (selectedCommit)
			refish = selectedCommit;
		else
			refish = repository.currentBranch.ref;
	}

	[PBCreateTagSheet beginSheetWithRefish:refish windowController:self completionHandler:^(PBCreateTagSheet *sheet, NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) return;

		NSString *tagName = [sheet.tagNameField stringValue];
		NSString *message = [sheet.tagMessageText string];
		NSError *error = nil;
		BOOL success = [self.repository createTag:tagName message:message atRefish:sheet.targetRefish error:&error];
		if (!success) {
			[self showErrorSheet:error];
		}
	}];
}

@end
