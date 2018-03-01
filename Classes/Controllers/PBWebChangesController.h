//
//  PBWebChangesController.h
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBWebController.h"
#import "PBGitCommitController.h"
#import "PBChangedFile.h"

@class PBGitIndexController;

@interface PBWebChangesController : PBWebController {
	IBOutlet NSArrayController *unstagedFilesController;
	IBOutlet NSArrayController *stagedFilesController;
	__weak IBOutlet PBGitCommitController *controller;
	IBOutlet PBGitIndexController *indexController;

	PBChangedFile *selectedFile;
	BOOL selectedFileIsCached;
}

- (void) refresh;
- (void) setStateMessage:(NSString *)state;

- (void) showMultiple:(NSArray *)files;
@end
