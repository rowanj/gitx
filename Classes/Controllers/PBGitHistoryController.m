//
//  PBGitHistoryView.m
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>

#import "PBGitCommit.h"
#import "PBGitTree.h"
#import "PBGitRef.h"
#import "PBGitHistoryList.h"
#import "PBGitRevSpecifier.h"
#import "PBGitHistoryController.h"
#import "PBWebHistoryController.h"
#import "PBGitGrapher.h"
#import "PBGitRevisionCell.h"
#import "PBCommitList.h"
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBAddRemoteSheet.h"
#import "PBGitSidebarController.h"
#import "PBGitGradientBarView.h"
#import "PBDiffWindowController.h"
#import "PBGitDefaults.h"
#import "PBGitRevList.h"
#import "PBHistorySearchController.h"
#import "PBGitRepositoryWatcher.h"
#import "PBQLTextView.h"
#import "GLFileView.h"
#import "GitXCommitCopier.h"
#import "NSSplitView+GitX.h"
#import "PBRefMenuItem.h"
#import "PBGitStash.h"

#define kHistorySelectedDetailIndexKey @"PBHistorySelectedDetailIndex"
#define kHistoryDetailViewIndex 0
#define kHistoryTreeViewIndex 1

@interface PBGitHistoryController ()

- (void) updateBranchFilterMatrix;
- (void) restoreFileBrowserSelection;
- (void) saveFileBrowserSelection;

@end


@implementation PBGitHistoryController
@synthesize webCommits, gitTree, commitController, refController;
@synthesize searchController;
@synthesize commitList;
@synthesize treeController;
@synthesize selectedCommits;

- (void)awakeFromNib
{
	[historySplitView pb_restoreAutosavedPositions];

	self.selectedCommitDetailsIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kHistorySelectedDetailIndexKey];

	[commitController addObserver:self forKeyPath:@"selection" options:0 context:@"commitChange"];
	[commitController addObserver:self forKeyPath:@"arrangedObjects.@count" options:NSKeyValueObservingOptionInitial context:@"updateCommitCount"];
	[treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeChange"];

	[repository.revisionList addObserver:self forKeyPath:@"isUpdating" options:0 context:@"revisionListUpdating"];
	[repository addObserver:self forKeyPath:@"currentBranch" options:0 context:@"branchChange"];
	[repository addObserver:self forKeyPath:@"refs" options:0 context:@"updateRefs"];
	[repository addObserver:self forKeyPath:@"currentBranchFilter" options:0 context:@"branchFilterChange"];

	forceSelectionUpdate = YES;
	NSSize cellSpacing = [commitList intercellSpacing];
	cellSpacing.height = 0;
	[commitList setIntercellSpacing:cellSpacing];
	[fileBrowser setTarget:self];
	[fileBrowser setDoubleAction:@selector(openSelectedFile:)];

	if (!repository.currentBranch) {
		[repository reloadRefs];
		[repository readCurrentBranch];
	}
	else
		[repository lazyReload];

    if (![repository hasSVNRemote])
    {
        // Remove the SVN revision table column for repositories with no SVN remote configured
        [commitList removeTableColumn:[commitList tableColumnWithIdentifier:@"GitSVNRevision"]];
    }

	// Set a sort descriptor for the subject column in the history list, as
	// It can't be sorted by default (because it's bound to a PBGitCommit)
	[[commitList tableColumnWithIdentifier:@"SubjectColumn"] setSortDescriptorPrototype:[[NSSortDescriptor alloc] initWithKey:@"subject" ascending:YES]];
	// Add a menu that allows a user to select which columns to view
	[[commitList headerView] setMenu:[self tableColumnMenu]];

	[upperToolbarView setTopShade:237/255.0f bottomShade:216/255.0f];
	[scopeBarView setTopColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.068 brightness:0.898 alpha:1.000] 
				  bottomColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.119 brightness:0.765 alpha:1.000]];
	[self updateBranchFilterMatrix];

	// listen for updates
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repositoryUpdatedNotification:) name:PBGitRepositoryEventNotification object:repository];

	__unsafe_unretained PBGitHistoryController *weakSelf = self;
	commitList.findPanelActionBlock = ^(id sender) {
		[weakSelf.view.window makeFirstResponder:weakSelf->searchField];
	};

	[super awakeFromNib];
}

- (void) _repositoryUpdatedNotification:(NSNotification *)notification {
    PBGitRepositoryWatcherEventType eventType = [(NSNumber *)[[notification userInfo] objectForKey:kPBGitRepositoryEventTypeUserInfoKey] unsignedIntValue];
    if(eventType & PBGitRepositoryWatcherEventTypeGitDirectory){
      // refresh if the .git repository is modified
      [self refresh:NULL];
    }
}

- (void) updateKeys
{
	NSArray<PBGitCommit *> *newSelectedCommits = commitController.selectedObjects;
	if  (![self.selectedCommits isEqualToArray:newSelectedCommits]) {
		self.selectedCommits = newSelectedCommits;
	}
	
	PBGitCommit *firstSelectedCommit = self.selectedCommits.firstObject;
	
	if (self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) {
		self.gitTree = firstSelectedCommit.tree;
		[self restoreFileBrowserSelection];
	}
	else {
		// kHistoryDetailViewIndex
		if (![self.webCommits isEqualToArray:self.selectedCommits]) {
			self.webCommits = self.selectedCommits;
		}
	}
}

- (BOOL) singleCommitSelected
{
	return self.selectedCommits.count == 1;
}

+ (NSSet *) keyPathsForValuesAffectingSingleCommitSelected {
	return [NSSet setWithObjects:@"selectedCommits", nil];
}

- (BOOL) singleNonHeadCommitSelected
{
	return self.singleCommitSelected
		&& ![self.selectedCommits.firstObject isOnHeadBranch];
}

+ (NSSet *) keyPathsForValuesAffectingSingleNonHeadCommitSelected {
	return [self keyPathsForValuesAffectingSingleCommitSelected];
}

- (void) updateBranchFilterMatrix
{
	if ([repository.currentBranch isSimpleRef]) {
		[allBranchesFilterItem setEnabled:YES];
		[localRemoteBranchesFilterItem setEnabled:YES];

		NSInteger filter = repository.currentBranchFilter;
		[allBranchesFilterItem setState:(filter == kGitXAllBranchesFilter)];
		[localRemoteBranchesFilterItem setState:(filter == kGitXLocalRemoteBranchesFilter)];
		[selectedBranchFilterItem setState:(filter == kGitXSelectedBranchFilter)];
	}
	else {
		[allBranchesFilterItem setState:NO];
		[localRemoteBranchesFilterItem setState:NO];

		[allBranchesFilterItem setEnabled:NO];
		[localRemoteBranchesFilterItem setEnabled:NO];

		[selectedBranchFilterItem setState:YES];
	}

	[selectedBranchFilterItem setTitle:[repository.currentBranch title]];
	[selectedBranchFilterItem sizeToFit];

	[localRemoteBranchesFilterItem setTitle:[[repository.currentBranch ref] isRemote]
		? NSLocalizedString(@"Remote", @"Filter button for all remote commits in history view")
		: NSLocalizedString(@"Local", @"Filter button for all local commits in history view")];
}

- (PBGitCommit *) firstCommit
{
	NSArray *arrangedObjects = [commitController arrangedObjects];
	if ([arrangedObjects count] > 0)
		return [arrangedObjects objectAtIndex:0];

	return nil;
}

- (BOOL)isCommitSelected
{
	return [self.selectedCommits isEqualToArray:[commitController selectedObjects]];
}

- (void) setSelectedCommitDetailsIndex:(NSInteger)detailsIndex
{
	if (selectedCommitDetailsIndex == detailsIndex)
		return;

	selectedCommitDetailsIndex = detailsIndex;
	[[NSUserDefaults standardUserDefaults] setInteger:selectedCommitDetailsIndex forKey:kHistorySelectedDetailIndexKey];
	forceSelectionUpdate = YES;
	[self updateKeys];
}

- (NSInteger) selectedCommitDetailsIndex
{
	return selectedCommitDetailsIndex;
}

- (void) updateStatus
{
	self.isBusy = repository.revisionList.isUpdating;
	self.status = [NSString stringWithFormat:@"%lu commits loaded", [[commitController arrangedObjects] count]];
}

- (void) restoreFileBrowserSelection
{
	if (self.selectedCommitDetailsIndex != kHistoryTreeViewIndex)
		return;

	NSArray *children = [treeController content];
	if ([children count] == 0)
		return;

	NSIndexPath *path = [[NSIndexPath alloc] init];
	if ([currentFileBrowserSelectionPath count] == 0)
		path = [path indexPathByAddingIndex:0];
	else {
		for (NSString *pathComponent in currentFileBrowserSelectionPath) {
			PBGitTree *child = nil;
			NSUInteger childIndex = 0;
			for (child in children) {
				if ([child.path isEqualToString:pathComponent]) {
					path = [path indexPathByAddingIndex:childIndex];
					children = child.children;
					break;
				}
				childIndex++;
			}
			if (!child)
				return;
		}
	}

	[treeController setSelectionIndexPath:path];
}

- (void) saveFileBrowserSelection
{
	NSArray *objects = [treeController selectedObjects];
	NSArray *content = [treeController content];

	if ([objects count] && [content count]) {
		PBGitTree *treeItem = [objects objectAtIndex:0];
		currentFileBrowserSelectionPath = [treeItem.fullPath componentsSeparatedByString:@"/"];
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSString* strContext = (__bridge NSString*)context;
    if ([strContext isEqualToString: @"commitChange"]) {
		[self updateKeys];
		[self restoreFileBrowserSelection];
		return;
	}

	if ([strContext isEqualToString: @"treeChange"]) {
		[self updateQuicklookForce: NO];
		[self saveFileBrowserSelection];
		return;
	}

	if([strContext isEqualToString:@"branchChange"]) {
		// Reset the sorting
		if ([[commitController sortDescriptors] count])
			[commitController setSortDescriptors:[NSArray array]];
		[self updateBranchFilterMatrix];
		return;
	}

	if([strContext isEqualToString:@"updateRefs"]) {
		[commitController rearrangeObjects];
		return;
	}

	if ([strContext isEqualToString:@"branchFilterChange"]) {
		[PBGitDefaults setBranchFilter:repository.currentBranchFilter];
		[self updateBranchFilterMatrix];
		return;
	}

	if([strContext isEqualToString:@"updateCommitCount"] || [(__bridge NSString *)context isEqualToString:@"revisionListUpdating"]) {
		[self updateStatus];

		if ([repository.currentBranch isSimpleRef])
			[self selectCommit:[repository OIDForRef:repository.currentBranch.ref]];
		else
			[self selectCommit:self.firstCommit.OID];
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (IBAction) openSelectedFile:(id)sender
{
	NSArray* selectedFiles = [treeController selectedObjects];
	if ([selectedFiles count] == 0)
		return;
	PBGitTree* tree = [selectedFiles objectAtIndex:0];
	NSString* name = [tree tmpFileNameForContents];
	[[NSWorkspace sharedWorkspace] openFile:name];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = menuItem.action;

    if (action == @selector(setDetailedView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryDetailViewIndex) ? NSOnState : NSOffState];
    } else if (action == @selector(setTreeView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) ? NSOnState : NSOffState];
	}
	
	if ([self respondsToSelector:action]) {
		if (action == @selector(createBranch:) || action == @selector(createTag:)) {
			return self.singleCommitSelected;
		}
		
        return YES;
	}

	if (action == @selector(copy:)
		|| action == @selector(copySHA:)
		|| action == @selector(copyShortName:)
		|| action == @selector(copyPatch:)) {
		return self.commitController.selectedObjects.count > 0;
	}
	
    return [[self nextResponder] validateMenuItem:menuItem];
}

- (IBAction) setDetailedView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryDetailViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setTreeView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryTreeViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setBranchFilter:(id)sender
{
	repository.currentBranchFilter = [(NSView*)sender tag];
	[PBGitDefaults setBranchFilter:repository.currentBranchFilter];
	[self updateBranchFilterMatrix];
	forceSelectionUpdate = YES;
}

- (void)keyDown:(NSEvent*)event
{
	if ([[event charactersIgnoringModifiers] isEqualToString: @"f"] && [event modifierFlags] & NSAlternateKeyMask && [event modifierFlags] & NSCommandKeyMask)
		[superController.window makeFirstResponder: searchField];
	else
		[super keyDown: event];
}

// NSSearchField (actually textfields in general) prevent the normal Find operations from working. Setup custom actions for the
// next and previous menuitems (in MainMenu.nib) so they will work when the search field is active. When searching for text in
// a file make sure to call the Find panel's action method instead.
- (IBAction)selectNext:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectNextResult];
}
- (IBAction)selectPrevious:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectPreviousResult];
}

- (IBAction) copy:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toSHAAndHeadingString:commitController.selectedObjects]];
}

- (IBAction) copySHA:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toFullSHA:commitController.selectedObjects]];
}

- (IBAction) copyShortName:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toShortName:commitController.selectedObjects]];
}

- (IBAction) copyPatch:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toPatch:commitController.selectedObjects]];
}

- (IBAction) toggleQLPreviewPanel:(id)sender
{
	if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	else
		[[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
}

- (void) updateQuicklookForce:(BOOL)force
{
	if (!force && (![QLPreviewPanel sharedPreviewPanelExists] || ![[QLPreviewPanel sharedPreviewPanel] isVisible]))
		return;

	[[QLPreviewPanel sharedPreviewPanel] reloadData];
}

- (IBAction) refresh:(id)sender
{
	[repository forceUpdateRevisions];
}

- (void) updateView
{
	[self updateKeys];
}

- (NSResponder *)firstResponder;
{
	return commitList;
}

- (void) scrollSelectionToTopOfViewFrom:(NSInteger)oldIndex
{
	if (oldIndex == NSNotFound)
		oldIndex = 0;

	NSInteger newIndex = commitController.selectionIndexes.firstIndex;

	if (newIndex > oldIndex) {
        CGFloat sviewHeight = commitList.superview.bounds.size.height;
        CGFloat rowHeight = commitList.rowHeight;
		NSInteger visibleRows = lround(sviewHeight / rowHeight);
		newIndex += (visibleRows - 1);
		if (newIndex >= [commitController.content count])
			newIndex = [commitController.content count] - 1;
	}

    if (newIndex != oldIndex) {
        commitList.useAdjustScroll = YES;
    }

	[commitList scrollRowToVisible:newIndex];
    commitList.useAdjustScroll = NO;
}

- (NSArray *) selectedObjectsForOID:(GTOID *)commitOID
{
	NSPredicate *selection = [NSPredicate predicateWithFormat:@"OID == %@", commitOID];
	NSArray *selectionCommits = [[commitController content] filteredArrayUsingPredicate:selection];

	if ((selectionCommits.count == 0) && [self firstCommit] != nil) {
		selectionCommits = @[[self firstCommit]];
	}
	
	return selectionCommits;
}

- (void)selectCommit:(GTOID *)commitOID
{
	if (!forceSelectionUpdate && [[[commitController.selectedObjects lastObject] OID] isEqual:commitOID]) {
		return;
	}

	NSArray *selectedObjects = [self selectedObjectsForOID:commitOID];
	[commitController setSelectedObjects:selectedObjects];

	NSInteger oldIndex = [[commitController selectionIndexes] firstIndex];
	[self scrollSelectionToTopOfViewFrom:oldIndex];

	forceSelectionUpdate = NO;
}

- (BOOL) hasNonlinearPath
{
	return [commitController filterPredicate] || [[commitController sortDescriptors] count] > 0;
}

- (void)closeView
{
	if (commitController) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
		[commitController removeObserver:self forKeyPath:@"selection"];
		[commitController removeObserver:self forKeyPath:@"arrangedObjects.@count"];
		[treeController removeObserver:self forKeyPath:@"selection"];

		[repository.revisionList removeObserver:self forKeyPath:@"isUpdating"];
		[repository removeObserver:self forKeyPath:@"currentBranch"];
		[repository removeObserver:self forKeyPath:@"refs"];
		[repository removeObserver:self forKeyPath:@"currentBranchFilter"];
	}

	[webHistoryController closeView];
	[fileView closeView];

	[super closeView];
}

#pragma mark Table Column Methods
- (NSMenu *)tableColumnMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	for (NSTableColumn *column in [commitList tableColumns]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:[[column headerCell] stringValue]];
		[item bind:@"value"
		  toObject:column
	   withKeyPath:@"hidden"
		   options:[NSDictionary dictionaryWithObject:@"NSNegateBoolean" forKey:NSValueTransformerNameBindingOption]];
		[menu addItem:item];
	}
	return menu;
}

#pragma mark Tree Context Menu Methods

- (void)showCommitsFromTree:(id)sender
{
	NSString *searchString = [(NSArray *)[sender representedObject] componentsJoinedByString:@" "];
	[searchController setHistorySearch:searchString mode:PBHistorySearchModePath];
}

- (void) checkoutFiles:(id)sender
{
	NSMutableArray *files = [NSMutableArray array];
	for (NSString *filePath in [sender representedObject])
		[files addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	NSError *error = nil;
	BOOL success = [repository checkoutFiles:files fromRefish:self.selectedCommits.firstObject error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}

}

- (void) diffFilesAction:(id)sender
{
	/* TODO: Move that to the document */
	[PBDiffWindowController showDiffWindowWithFiles:[sender representedObject] fromCommit:self.selectedCommits.firstObject diffCommit:nil];
}

- (NSMenu *)contextMenuForTreeView
{
	NSArray *filePaths = [[treeController selectedObjects] valueForKey:@"fullPath"];

	NSMenu *menu = [[NSMenu alloc] init];
	for (NSMenuItem *item in [self menuItemsForPaths:filePaths])
		[menu addItem:item];
	return menu;
}

- (NSArray *)menuItemsForPaths:(NSArray *)paths
{
	NSMutableArray *filePaths = [NSMutableArray array];
	for (NSString *filePath in paths)
		[filePaths addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	BOOL multiple = [filePaths count] != 1;
	NSString *historyItemTitle = multiple
		? NSLocalizedString(@"Show history of files", @"Show history menu item for multiple files")
		: NSLocalizedString(@"Show history of file", @"Show history menu item for single file");
	NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:historyItemTitle
														 action:@selector(showCommitsFromTree:)
												  keyEquivalent:@""];

	PBGitRef *headRef = [[repository headRef] ref];
	NSString *headRefName = [headRef shortName];
	NSString *diffTitleFormat = multiple
		? NSLocalizedString(@"Diff files with %@", @"Diff with ref menu item for multiple files")
		: NSLocalizedString(@"Diff file with %@", @"Diff with ref menu item for single file");
	NSString *diffTitle = [NSString stringWithFormat:diffTitleFormat, headRefName];
	BOOL isHead = [self.selectedCommits.firstObject.OID isEqual:repository.headOID];
	NSMenuItem *diffItem = [[NSMenuItem alloc] initWithTitle:diffTitle
													  action:isHead ? nil : @selector(diffFilesAction:)
											   keyEquivalent:@""];

	NSString *checkoutItemTitle = multiple
		? NSLocalizedString(@"Checkout files", @"Checkout menu item for multiple files")
		: NSLocalizedString(@"Checkout file", @"Checkout menu item for single file");
	NSMenuItem *checkoutItem = [[NSMenuItem alloc] initWithTitle:checkoutItemTitle
														  action:@selector(checkoutFiles:)
												   keyEquivalent:@""];
	
	NSString *finderItemTitle = NSLocalizedString(@"Reveal in Finder", @"Show in Finder menu item");
	NSMenuItem *finderItem = [[NSMenuItem alloc] initWithTitle:finderItemTitle
														action:@selector(revealInFinder:)
												 keyEquivalent:@""];
	
	NSString *openFilesItemTitle = multiple
		? NSLocalizedString(@"Open Files", @"Open menu item for multiple files")
		: NSLocalizedString(@"Open File", @"Open menu item for single file");
	NSMenuItem *openFilesItem = [[NSMenuItem alloc] initWithTitle:openFilesItemTitle
														   action:@selector(openFiles:)
													keyEquivalent:@""];

	NSArray *menuItems = [NSArray arrayWithObjects:historyItem, diffItem, checkoutItem, finderItem, openFilesItem, nil];
	for (NSMenuItem *item in menuItems) {
		[item setRepresentedObject:filePaths];
	}

	return menuItems;
}

#pragma mark Repository Methods

- (id <PBGitRefish>)refishForSender:(id)sender
{
	return [self refishForSender:sender refishTypes:nil];
}

- (id <PBGitRefish>)refishForSender:(id)sender refishTypes:(NSArray *)types
{
	if ([sender isKindOfClass:[PBRefMenuItem class]]) {
		id <PBGitRefish> refish = [[(PBRefMenuItem *)sender refishs] firstObject];

		if (!types || [types indexOfObject:[refish refishType]] != NSNotFound)
			return refish;
		return nil;
	}

	if ([types indexOfObject:kGitXCommitType] == NSNotFound)
		return nil;

	return self.selectedCommits.firstObject;
}

- (IBAction)fetchRemote:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	[self.windowController performFetchForRef:refish];
}

- (IBAction)pullRemote:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	[self.windowController performPullForBranch:refish remote:nil rebase:NO];
}

- (IBAction)pushUpdatesToRemote:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	PBGitRef *remoteRef = nil; // [(PBGitRef *)sender.refishs.firstObject remoteRef];

	[self.windowController performPushForBranch:nil toRemote:remoteRef];
}

- (IBAction)pushDefaultRemoteForRef:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	PBGitRef *ref = nil;

	[self.windowController performPushForBranch:ref toRemote:nil];
}

- (IBAction)pushToRemote:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	PBGitRef *ref = nil;
	NSString *remoteName = [sender representedObject];
	PBGitRef *remoteRef = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:remoteName]];

	[self.windowController performPushForBranch:ref toRemote:remoteRef];
}

- (IBAction)merge:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType, kGitXRemoteBranchType, kGitXCommitType, kGitXTagType]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [repository mergeWithRefish:refish error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
}

- (IBAction)checkout:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType, kGitXRemoteBranchType, kGitXCommitType, kGitXTagType]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [repository checkoutRefish:refish error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
}

- (IBAction)cherryPick:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXCommitType]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [repository cherryPickRefish:refish error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
}

- (IBAction)rebase:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType, kGitXRemoteBranchType]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [repository rebaseBranch:nil onRefish:refish error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
}

- (IBAction) rebaseHeadBranch:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType, kGitXRemoteBranchType]];
	NSError *error = nil;
	BOOL success = [self.repository rebaseBranch:nil onRefish:refish error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}
}

- (IBAction)showDeleteRefSheet:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXBranchType]];
	if (!refish)
		return;

	PBGitRef *ref = (PBGitRef *)refish;

	void (^performDelete)(void) = ^{
		NSError *error = nil;
		BOOL success = [self.repository deleteRef:ref error:&error];
		if (!success) {
			[self.windowController showErrorSheet:error];
		}
		return;
	};

	if ([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogDeleteRef]) {
		performDelete();
		return;
	}

	NSString *ref_desc = [NSString stringWithFormat:@"%@ '%@'", [ref refishType], [ref shortName]];

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Delete %@?", ref_desc]
									 defaultButton:@"Delete"
								   alternateButton:@"Cancel"
									   otherButton:nil
						 informativeTextWithFormat:@"Are you sure you want to remove the %@?", ref_desc];
	[alert setShowsSuppressionButton:YES];

	[alert beginSheetModalForWindow:self.windowController.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if ([[alert suppressionButton] state] == NSOnState)
						  [PBGitDefaults suppressDialogWarningForDialog:kDialogDeleteRef];

					  if (returnCode == NSModalResponseOK) {
						  performDelete();
					  }
				  }];
}

- (IBAction)diffWithHEAD:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:nil];
	if (!refish)
		return;

	PBGitCommit *commit = [self.repository commitForRef:refish];

	NSString *diff = [self.repository performDiff:commit against:nil forFiles:nil];

	[PBDiffWindowController showDiff:diff];
}

- (IBAction)stashPop:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXStashType]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	NSError *error = nil;
	BOOL success = [self.repository stashPop:stash error:&error];

	if (!success) {
		[self.windowController showErrorSheet:error];
	} else {
		[self.windowController showCommitView:sender];
	}
}

- (IBAction)stashApply:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXStashType]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	NSError *error = nil;
	BOOL success = [self.repository stashApply:stash error:&error];

	if (!success) {
		[self.windowController showErrorSheet:error];
	} else {
		[self.windowController showCommitView:sender];
	}
}

- (IBAction)stashDrop:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXStashType]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	NSError *error = nil;
	BOOL success = [self.repository stashDrop:stash error:&error];

	if (!success) {
		[self.windowController showErrorSheet:error];
	} else {
		[self.windowController showHistoryView:sender];
	}
}

- (IBAction)stashViewDiff:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXStashType]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	[PBDiffWindowController showDiffWindowWithFiles:nil fromCommit:stash.ancestorCommit diffCommit:stash.commit];
}

- (IBAction)showTagInfoSheet:(id)sender
{
	id <PBGitRefish> refish = [self refishForSender:sender refishTypes:@[kGitXTagType]];
	if (!refish)
		return;

	PBGitRef *ref = (PBGitRef *)refish;

	NSError *error = nil;
	NSString *tagName = [ref tagName];
	NSString *tagRef = [@"refs/tags/" stringByAppendingString:tagName];
	GTObject *object = [self.repository.gtRepo lookUpObjectByRevParse:tagRef error:&error];
	if (!object) {
		NSLog(@"Couldn't look up ref %@:%@", tagRef, [error debugDescription]);
		return;
	}
	NSString *title = [NSString stringWithFormat:@"Info for tag: %@", tagName];
	NSString *info = @"";
	if ([object isKindOfClass:[GTTag class]]) {
		GTTag *tag = (GTTag*)object;
		info = tag.message;
	}

	[self.windowController showMessageSheet:title infoText:info];
}

#pragma mark -
#pragma mark Quick Look

#pragma mark <QLPreviewPanelDataSource>

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
    return [[fileBrowser selectedRowIndexes] count];
}

- (id <QLPreviewItem>)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index
{
	PBGitTree *treeItem = (PBGitTree *)[[treeController selectedObjects] objectAtIndex:index];
	NSURL *previewURL = [NSURL fileURLWithPath:[treeItem tmpFileNameForContents]];

    return (id <QLPreviewItem>)previewURL;
}

#pragma mark <QLPreviewPanelDelegate>

- (BOOL)previewPanel:(id)panel handleEvent:(NSEvent *)event
{
    // redirect all key down events to the table view
    if ([event type] == NSKeyDown) {
        [fileBrowser keyDown:event];
        return YES;
    }
    return NO;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
    NSInteger index = [fileBrowser rowForItem:[[treeController selectedNodes] objectAtIndex:0]];
    if (index == NSNotFound) {
        return NSZeroRect;
    }

    NSRect iconRect = [fileBrowser frameOfCellAtColumn:0 row:index];

    // check that the icon rect is visible on screen
    NSRect visibleRect = [fileBrowser visibleRect];

    if (!NSIntersectsRect(visibleRect, iconRect)) {
        return NSZeroRect;
    }

    // convert icon rect to screen coordinates
	iconRect = [fileBrowser.window.contentView convertRect:iconRect fromView:fileBrowser];
	iconRect = [fileBrowser.window convertRectToScreen:iconRect];

    return iconRect;
}

@end
