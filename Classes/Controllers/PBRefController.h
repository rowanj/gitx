//
//  PBRefController.h
//  GitX
//
//  Created by Pieter de Bie on 21-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBRefContextDelegate.h"

@class PBGitHistoryController, PBCommitList;

@interface PBRefController : NSObject <PBRefContextDelegate> {
	__weak IBOutlet PBGitHistoryController *historyController;
	__weak IBOutlet NSArrayController *commitController;
	__weak IBOutlet PBCommitList *commitList;
}

@end
