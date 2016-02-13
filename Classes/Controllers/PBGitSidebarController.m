//
//  PBGitSidebar.m
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PBGitSidebarController.h"
#import "PBSourceViewItems.h"
#import "PBGitHistoryController.h"
#import "PBGitCommitController.h"
#import "PBRefController.h"
#import "PBSourceViewCell.h"
#import "NSOutlineViewExt.h"
#import "PBAddRemoteSheet.h"
#import "PBGitDefaults.h"
#import "PBHistorySearchController.h"

@interface PBGitSidebarController ()

- (void)populateList;
- (PBSourceViewItem *)addRevSpec:(PBGitRevSpecifier *)revSpec;
- (PBSourceViewItem *)itemForRev:(PBGitRevSpecifier *)rev;
- (void) removeRevSpec:(PBGitRevSpecifier *)rev;
- (void) updateActionMenu;
- (void) updateRemoteControls;
@end

@implementation PBGitSidebarController
@synthesize items;
@synthesize sourceListControlsView;
@synthesize historyViewController;
@synthesize commitViewController;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	self = [super initWithRepository:theRepository superController:controller];
	[sourceView setDelegate:self];
	items = [NSMutableArray array];

	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	window.contentView = self.view;
	[self populateList];

	historyViewController = [[PBGitHistoryController alloc] initWithRepository:repository superController:superController];
	commitViewController = [[PBGitCommitController alloc] initWithRepository:repository superController:superController];

	[repository addObserver:self forKeyPath:@"currentBranch" options:0 context:@"currentBranchChange"];
	[repository addObserver:self forKeyPath:@"branches" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:@"branchesModified"];

    [sourceView setTarget:self];
    [sourceView setDoubleAction:@selector(doubleClicked:)];

	[self menuNeedsUpdate:[actionButton menu]];

	if ([PBGitDefaults showStageView])
		[self selectStage];
	else
		[self selectCurrentBranch];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(expandCollapseItem:) name:NSOutlineViewItemWillExpandNotification object:sourceView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(expandCollapseItem:) name:NSOutlineViewItemWillCollapseNotification object:sourceView];

}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewItemWillExpandNotification object:sourceView];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewItemWillCollapseNotification object:sourceView];
}

- (void)closeView
{
	[historyViewController closeView];
	[commitViewController closeView];

	[repository removeObserver:self forKeyPath:@"currentBranch"];
	[repository removeObserver:self forKeyPath:@"branches"];

	[super closeView];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([@"currentBranchChange" isEqualToString:(__bridge NSString*)context]) {
		[sourceView reloadData];
		[self selectCurrentBranch];
		return;
	}

	if ([@"branchesModified" isEqualToString:(__bridge NSString*)context]) {
		NSInteger changeKind = [(NSNumber *)[change objectForKey:NSKeyValueChangeKindKey] intValue];

		if (changeKind == NSKeyValueChangeInsertion) {
			NSArray *newRevSpecs = [change objectForKey:NSKeyValueChangeNewKey];
			for (PBGitRevSpecifier *rev in newRevSpecs) {
				PBSourceViewItem *item = [self addRevSpec:rev];
				[sourceView PBExpandItem:item expandParents:YES];
			}
		}
		else if (changeKind == NSKeyValueChangeRemoval) {
			NSArray *removedRevSpecs = [change objectForKey:NSKeyValueChangeOldKey];
			for (PBGitRevSpecifier *rev in removedRevSpecs)
				[self removeRevSpec:rev];
		}
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (PBSourceViewItem *) selectedItem
{
	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];

	return item;
}

- (void) selectStage
{
	NSIndexSet *index = [NSIndexSet indexSetWithIndex:[sourceView rowForItem:stage]];
	[sourceView selectRowIndexes:index byExtendingSelection:NO];
}

- (void) selectCurrentBranch
{
	PBGitRevSpecifier *rev = repository.currentBranch;
	if (!rev) {
		[repository reloadRefs];
		[repository readCurrentBranch];
		return;
	}

	PBSourceViewItem *item = [self addRevSpec:rev];
    if (item) {
        [sourceView reloadData];
	
        [sourceView PBExpandItem:item expandParents:YES];
        NSIndexSet *index = [NSIndexSet indexSetWithIndex:[sourceView rowForItem:item]];
	
        [sourceView selectRowIndexes:index byExtendingSelection:NO];
    }
}

- (PBSourceViewItem *) itemForRev:(PBGitRevSpecifier *)rev
{
	PBSourceViewItem *foundItem = nil;
	for (PBSourceViewItem *item in items)
		if ( (foundItem = [item findRev:rev]) != nil )
			return foundItem;
	return nil;
}

- (PBSourceViewItem *)addRevSpec:(PBGitRevSpecifier *)rev
{
    PBSourceViewItem *item = nil;
    for (PBSourceViewItem *it in items)
        if ( (item = [it findRev:rev]) != nil )
            return item;

	if (![rev isSimpleRef]) {
		[others addChild:[PBSourceViewItem itemWithRevSpec:rev]];
		return item;
	}

	NSArray *pathComponents = [[rev simpleRef] componentsSeparatedByString:@"/"];
	if ([pathComponents count] < 2)
		[branches addChild:[PBSourceViewItem itemWithRevSpec:rev]];
	else if ([[pathComponents objectAtIndex:1] isEqualToString:@"heads"])
		[branches addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
	else if ([[rev simpleRef] hasPrefix:@"refs/tags/"])
		[tags addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
	else if ([[rev simpleRef] hasPrefix:@"refs/remotes/"])
		[remotes addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
    return item;
}

- (void) removeRevSpec:(PBGitRevSpecifier *)rev
{
	PBSourceViewItem *item = [self itemForRev:rev];

	if (!item)
		return;

	PBSourceViewItem *parent = item.parent;
	[parent removeChild:item];
	[sourceView reloadData];
}

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode
{
	[historyViewController.searchController setHistorySearch:searchString mode:mode];
}

#pragma mark NSOutlineView delegate methods

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];

	if ([item revSpecifier]) {
		if (![repository.currentBranch isEqual:[item revSpecifier]])
			repository.currentBranch = [item revSpecifier];
		[superController changeContentController:historyViewController];
		[PBGitDefaults setShowStageView:NO];
	}

	if (item == stage) {
		[superController changeContentController:commitViewController];
		[PBGitDefaults setShowStageView:YES];
	}

	[self updateActionMenu];
	[self updateRemoteControls];
}

- (void)doubleClicked:(id)object {
    NSInteger rowNumber = [sourceView selectedRow];
    if ([[sourceView itemAtRow:rowNumber] isKindOfClass:[PBGitSVSubmoduleItem class]]) {
        PBGitSVSubmoduleItem *subModule = [sourceView itemAtRow:rowNumber];

		NSURL *url = subModule.path;
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url
																			   display:YES
																	 completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
																		 if (error) {
																			 [self.repository.windowController showErrorSheet:error];
																		 }
																	 }];
        ;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[PBGitSVSubmoduleItem class]]) {
        NSLog(@"hi");
    }
    return NO;
}
#pragma mark NSOutlineView delegate methods
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [item isGroupItem];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(PBSourceViewCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(PBSourceViewItem *)item
{
	cell.isCheckedOut = [item.revSpecifier isEqual:[repository headRef]];
	[cell setImage:[item icon]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return ![item isGroupItem];
}

//
// The next method is necessary to hide the triangle for uncollapsible items
// That is, items which should always be displayed, such as the Project group.
// This also moves the group item to the left edge.
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	return ![item isUncollapsible];
}

- (void)populateList
{
	PBSourceViewItem *project = [PBSourceViewItem groupItemWithTitle:[repository projectName]];
	project.isUncollapsible = YES;

	stage = [PBGitSVStageItem stageItem];
	[project addChild:stage];
	
	branches = [PBSourceViewItem groupItemWithTitle:@"Branches"];
	remotes = [PBSourceViewItem groupItemWithTitle:@"Remotes"];
	tags = [PBSourceViewItem groupItemWithTitle:@"Tags"];
	submodules = [PBSourceViewItem groupItemWithTitle:@"Submodules"];
	others = [PBSourceViewItem groupItemWithTitle:@"Other"];

	for (PBGitRevSpecifier *rev in repository.branches) {
		[self addRevSpec:rev];
	}
    
    for (GTSubmodule *sub in repository.submodules) {
        [submodules addChild: [PBGitSVSubmoduleItem itemWithSubmodule:sub]];
	}
    
	[items addObject:project];
	[items addObject:branches];
	[items addObject:remotes];
	[items addObject:tags];
	[items addObject:submodules];
	[items addObject:others];

	[sourceView reloadData];
	[sourceView expandItem:project];
	[sourceView expandItem:branches expandChildren:YES];
	[sourceView expandItem:remotes];
    [sourceView expandItem:submodules];

	[sourceView reloadItem:nil reloadChildren:YES];
}

- (void)expandCollapseItem:(NSNotification*)aNotification
{
    NSObject* child = [[aNotification userInfo] valueForKey:@"NSObject"];
    if ([child isKindOfClass:[PBSourceViewItem class]]) {
        ((PBSourceViewItem*)child).isExpanded = [aNotification.name isEqualToString:NSOutlineViewItemWillExpandNotification];
    }
}

#pragma mark NSOutlineView Datasource methods

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (!item)
		return [items objectAtIndex:index];

	return [[(PBSourceViewItem *)item sortedChildren] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [[(PBSourceViewItem *)item sortedChildren] count];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!item)
		return [items count];

	return [[(PBSourceViewItem *)item sortedChildren] count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [(PBSourceViewItem *)item title];
}


#pragma mark Menus

- (void) updateActionMenu
{
	[actionButton setEnabled:([[self selectedItem] ref] != nil)];
}

- (void) addMenuItemsForRef:(PBGitRef *)ref toMenu:(NSMenu *)menu
{
	if (!ref)
		return;

	for (NSMenuItem *menuItem in [historyViewController.refController menuItemsForRef:ref])
		[menu addItem:menuItem];
}

- (NSMenuItem *) actionIconItem
{
	NSMenuItem *actionIconItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
	NSImage *actionIcon = [NSImage imageNamed:@"NSActionTemplate"];
	[actionIcon setSize:NSMakeSize(12, 12)];
	[actionIconItem setImage:actionIcon];

	return actionIconItem;
}

- (NSMenu *) menuForRow:(NSInteger)row
{
	PBSourceViewItem *viewItem = [sourceView itemAtRow:row];

	PBGitRef *ref = [viewItem ref];
	if (!ref)
		return nil;

	NSMenu *menu = [[NSMenu alloc] init];
	[menu setAutoenablesItems:NO];
	[self addMenuItemsForRef:ref toMenu:menu];

	return menu;
}

// delegate of the action menu
- (void) menuNeedsUpdate:(NSMenu *)menu
{
	[actionButton removeAllItems];
	[menu addItem:[self actionIconItem]];

	PBGitRef *ref = [[self selectedItem] ref];
	[self addMenuItemsForRef:ref toMenu:menu];
}


#pragma mark Remote controls

enum  {
	kAddRemoteSegment = 0,
	kFetchSegment = 1,
	kPullSegment = 2,
	kPushSegment = 3
};

- (void) updateRemoteControls
{
	BOOL hasRemote = NO;

	PBGitRef *ref = [[self selectedItem] ref];
	if ([ref isRemote] || ([ref isBranch] && [[repository remoteRefForBranch:ref error:NULL] remoteName]))
		hasRemote = YES;

	[remoteControls setEnabled:hasRemote forSegment:kFetchSegment];
	[remoteControls setEnabled:hasRemote forSegment:kPullSegment];
	[remoteControls setEnabled:hasRemote forSegment:kPushSegment];
}

- (IBAction) fetchPullPushAction:(id)sender
{
	NSInteger selectedSegment = [sender selectedSegment];

	if (selectedSegment == kAddRemoteSegment) {
		[[[PBAddRemoteSheet alloc] initWithRepository:repository] show];
		return;
	}

	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];
	PBGitRef *ref = [[item revSpecifier] ref];

	if (!ref && (item.parent == remotes))
		ref = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:[item title]]];

	if (![ref isRemote] && ![ref isBranch])
		return;

	PBGitRef *remoteRef = [repository remoteRefForBranch:ref error:NULL];
	if (!remoteRef)
		return;

	if (selectedSegment == kFetchSegment)
		[repository beginFetchFromRemoteForRef:ref];
	else if (selectedSegment == kPullSegment)
		[repository beginPullFromRemote:remoteRef forRef:ref];
	else if (selectedSegment == kPushSegment) {
		if ([ref isRemote])
			[historyViewController.refController showConfirmPushRefSheet:nil remote:remoteRef];
		else if ([ref isBranch])
			[historyViewController.refController showConfirmPushRefSheet:ref remote:remoteRef];
	}
}


@end
