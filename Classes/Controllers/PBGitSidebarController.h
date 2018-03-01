//
//  PBGitSidebar.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"
#import "PBHistorySearchMode.h"

@class PBSourceViewItem;
@class PBGitHistoryController;
@class PBGitCommitController;

@interface PBGitSidebarController : PBViewController<NSOutlineViewDelegate> {
	__weak IBOutlet NSWindow *window;
	__weak IBOutlet NSOutlineView *sourceView;
	__weak IBOutlet NSView *sourceListControlsView;
	__weak IBOutlet NSPopUpButton *actionButton;
	__weak IBOutlet NSSegmentedControl *remoteControls;

	NSMutableArray *items;

	/* Specific things */
	PBSourceViewItem *stage;

	PBSourceViewItem *branches, *remotes, *tags, *others, *submodules, *stashes;

	PBGitHistoryController *historyViewController;
	PBGitCommitController *commitViewController;
}

- (void) selectStage;
- (void) selectCurrentBranch;

- (NSMenu *) menuForRow:(NSInteger)row;
- (void) menuNeedsUpdate:(NSMenu *)menu;

- (IBAction) fetchPullPushAction:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode;

@property(readonly) NSMutableArray *items;
@property(readonly) PBSourceViewItem *remotes;
@property(readonly) NSOutlineView *sourceView;
@property(readonly) NSView *sourceListControlsView;
@property(readonly) PBGitHistoryController *historyViewController;
@property(readonly) PBGitCommitController *commitViewController;

@end
