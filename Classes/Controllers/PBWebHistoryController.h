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


@class GTOID;


@interface PBWebHistoryController : PBWebController {
	__weak IBOutlet PBGitHistoryController* historyController;
	__weak IBOutlet id<PBRefContextDelegate> contextMenuDelegate;

	GTOID *currentOID;
	NSString* diff;
}

- (void) sendKey: (NSString*) key;

@property (readonly) NSString* diff;

@end
