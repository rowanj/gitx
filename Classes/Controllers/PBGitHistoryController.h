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
@class PBGitSHA;
@class PBHistorySearchController;

@interface PBGitHistoryController : PBViewController {
	IBOutlet PBRefController *refController;
	IBOutlet __weak NSSearchField *searchField;
	IBOutlet NSArrayController* commitController;
	IBOutlet NSTreeController* treeController;
	IBOutlet __weak NSOutlineView* fileBrowser;
	NSArray *currentFileBrowserSelectionPath;
	IBOutlet __weak PBCommitList* commitList;
	IBOutlet __weak PBCollapsibleSplitView *historySplitView;
	IBOutlet PBWebHistoryController *webHistoryController;
    QLPreviewPanel* previewPanel;
	IBOutlet PBHistorySearchController *searchController;
	IBOutlet GLFileView *fileView;

	IBOutlet __weak PBGitGradientBarView *upperToolbarView;
	IBOutlet __weak NSButton *mergeButton;
	IBOutlet __weak NSButton *cherryPickButton;
	IBOutlet __weak NSButton *rebaseButton;

	IBOutlet __weak PBGitGradientBarView *scopeBarView;
	IBOutlet __weak NSButton *allBranchesFilterItem;
	IBOutlet __weak NSButton *localRemoteBranchesFilterItem;
	IBOutlet __weak NSButton *selectedBranchFilterItem;

	IBOutlet __weak id webView;
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
@property (weak, readonly) PBCommitList *commitList;

- (IBAction) setDetailedView:(id)sender;
- (IBAction) setTreeView:(id)sender;
- (IBAction) setBranchFilter:(id)sender;

- (void)selectCommit:(PBGitSHA *)commit;
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
