//
//  PBDetailController.h
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBViewController, PBGitSidebarController, PBGitCommitController, PBGitRepository;
@class RJModalRepoSheet;

@interface PBGitWindowController : NSWindowController<NSWindowDelegate> {
	PBViewController *contentController;

	PBGitSidebarController *sidebarController;
	__weak IBOutlet NSView *sourceListControlsView;
	__weak IBOutlet NSSplitView *splitView;
	__weak IBOutlet NSView *sourceSplitView;
	__weak IBOutlet NSView *contentSplitView;

	__weak IBOutlet NSTextField *statusField;
	__weak IBOutlet NSProgressIndicator *progressIndicator;

	PBViewController* viewController;
}

@property (nonatomic, weak)  PBGitRepository *repository;

- (id)initWithRepository:(PBGitRepository*)theRepository displayDefault:(BOOL)display;

- (void)changeContentController:(PBViewController *)controller;

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller GITX_DEPRECATED;
- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText GITX_DEPRECATED;
- (void)showErrorSheet:(NSError *)error GITX_DEPRECATED;
- (void)showErrorSheetTitle:(NSString *)title message:(NSString *)message arguments:(NSArray *)arguments output:(NSString *)output GITX_DEPRECATED;

- (void)showModalSheet:(RJModalRepoSheet*)sheet;
- (void)hideModalSheet:(RJModalRepoSheet*)sheet;

- (IBAction) showCommitView:(id)sender;
- (IBAction) showHistoryView:(id)sender;
- (IBAction) revealInFinder:(id)sender;
- (IBAction) openInTerminal:(id)sender;
- (IBAction) refresh:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

@end
