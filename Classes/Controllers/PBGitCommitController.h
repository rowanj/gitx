//
//  PBGitCommitController.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitIndexController, PBIconAndTextCell, PBWebChangesController, PBGitIndex;
@class PBNiceSplitView;

@interface PBGitCommitController : PBViewController {
	// This might have to transfer over to the PBGitRepository
	// object sometime
	PBGitIndex *index;
    
    BOOL stashKeepIndex;
	
	IBOutlet NSTextView *commitMessageView;
	IBOutlet NSArrayController *unstagedFilesController;
	IBOutlet NSArrayController *cachedFilesController;
    IBOutlet NSArrayController *trackedFilesController;
    
    IBOutlet NSTabView *controlsTabView;
	IBOutlet NSButton *commitButton;
	IBOutlet NSButton *stashButton;

	IBOutlet PBGitIndexController *indexController;
	IBOutlet PBWebChangesController *webController;
	IBOutlet PBNiceSplitView *commitSplitView;
}

@property(readonly) PBGitIndex *index;
@property(assign) BOOL stashKeepIndex;

- (IBAction) refresh:(id) sender;
- (IBAction) commit:(id) sender;
- (IBAction) forceCommit:(id) sender;
- (IBAction) signOff:(id)sender;
- (IBAction) stashChanges:(id) sender;
@end
