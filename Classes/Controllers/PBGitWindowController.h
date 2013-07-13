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

	IBOutlet __weak NSView *sourceListControlsView;
	IBOutlet __weak NSSplitView *splitView;
	IBOutlet __weak NSView *sourceSplitView;
	IBOutlet __weak NSView *contentSplitView;
	IBOutlet __weak NSTextField *statusField;
	IBOutlet __weak NSProgressIndicator *progressIndicator;
	IBOutlet __weak NSToolbarItem *terminalItem;
	IBOutlet __weak NSToolbarItem *finderItem;
}

@property (nonatomic, weak)  PBGitRepository *repository;

- (id)initWithRepository:(PBGitRepository*)theRepository displayDefault:(BOOL)display;

- (void)changeContentController:(PBViewController *)controller;

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller DEPRECATED;
- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText DEPRECATED;
- (void)showErrorSheet:(NSError *)error DEPRECATED;
- (void)showErrorSheetTitle:(NSString *)title message:(NSString *)message arguments:(NSArray *)arguments output:(NSString *)output DEPRECATED;

- (void)showModalSheet:(RJModalRepoSheet*)sheet;
- (void)hideModalSheet:(RJModalRepoSheet*)sheet;

- (IBAction) showCommitView:(id)sender;
- (IBAction) showHistoryView:(id)sender;
- (IBAction) revealInFinder:(id)sender;
- (IBAction) openInTerminal:(id)sender;
- (IBAction) refresh:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

@end
