//
//  PBWebGitController.h
//  GitTest
//
//  Created by Pieter de Bie on 14-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBWebController.h"

#import "PBGitCommit.h"
#import "PBGitHistoryController.h"
#import "PBRefContextDelegate.h"


@class PBGitSHA;


@interface PBWebHistoryController : PBWebController {
	IBOutlet PBGitHistoryController* historyController;
	IBOutlet id<PBRefContextDelegate> contextMenuDelegate;

	PBGitSHA* currentSha;
	NSString* diff;
}

- (void) changeContentTo: (PBGitCommit *) content;
- (void) sendKey: (NSString*) key;

@property (readonly) NSString* diff;
@end
