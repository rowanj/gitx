//
//  PBGitHistoryView.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitCommit;
@class PBGitTree;
@class PBCollapsibleSplitView;

@class PBGitSidebarController;
@class PBWebHistoryController;
@class PBGitGradientBarView;
@class PBRefController;
@class QLPreviewPanel;
@class PBCommitList;
@class GLFileView;
@class GTOID;
@class PBHistorySearchController;

@interface PBGitHistoryController : PBViewController {
	IBOutlet NSArrayController *commitController;
	IBOutlet NSTreeController *treeController;
	IBOutlet PBWebHistoryController *webHistoryController;
	IBOutlet GLFileView *fileView;
	IBOutlet PBRefController *refController;
	IBOutlet PBHistorySearchController *searchController;

	__weak IBOutlet NSSearchField *searchField;
	__weak IBOutlet NSOutlineView *fileBrowser;
	__weak IBOutlet PBCommitList *commitList;
	__weak IBOutlet PBCollapsibleSplitView *historySplitView;
	__weak IBOutlet PBGitGradientBarView *upperToolbarView;
	__weak IBOutlet NSButton *mergeButton;
	__weak IBOutlet NSButton *cherryPickButton;
	__weak IBOutlet NSButton *rebaseButton;
	__weak IBOutlet PBGitGradientBarView *scopeBarView;
	__weak IBOutlet NSButton *allBranchesFilterItem;
	__weak IBOutlet NSButton *localRemoteBranchesFilterItem;
	__weak IBOutlet NSButton *selectedBranchFilterItem;
	__weak IBOutlet id webView;

	NSArray *currentFileBrowserSelectionPath;
    QLPreviewPanel* previewPanel;
	int selectedCommitDetailsIndex;
	BOOL forceSelectionUpdate;
	PBGitTree *gitTree;
	PBGitCommit *webCommit;
	PBGitCommit *selectedCommit;
}

@property (readonly) NSTreeController* treeController;
@property (assign) int selectedCommitDetailsIndex;
@property  PBGitCommit *webCommit;
@property  PBGitTree* gitTree;
@property (readonly) NSArrayController *commitController;
@property (readonly) PBRefController *refController;
@property (readonly) PBHistorySearchController *searchController;
@property (readonly) PBCommitList *commitList;

- (IBAction) setDetailedView:(id)sender;
- (IBAction) setTreeView:(id)sender;
- (IBAction) setBranchFilter:(id)sender;

- (void)selectCommit:(GTOID *)commit;
- (IBAction) refresh:(id)sender;
- (IBAction) toggleQLPreviewPanel:(id)sender;
- (IBAction) openSelectedFile:(id)sender;
- (void) updateQuicklookForce: (BOOL) force;

// Context menu methods
- (NSMenu *)contextMenuForTreeView;
- (NSArray *)menuItemsForPaths:(NSArray *)paths;
- (void)showCommitsFromTree:(id)sender;
- (void)showInFinderAction:(id)sender;
- (void)openFilesAction:(id)sender;

// Repository Methods
- (IBAction) createBranch:(id)sender;
- (IBAction) createTag:(id)sender;
- (IBAction) showAddRemoteSheet:(id)sender;
- (IBAction) merge:(id)sender;
- (IBAction) cherryPick:(id)sender;
- (IBAction) rebase:(id)sender;

// Find/Search methods
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;

- (void) copyCommitInfo;
- (void) copyCommitSHA;

- (BOOL) hasNonlinearPath;

- (NSMenu *)tableColumnMenu;

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview;
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset;
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset;

@end
