//
//  PBLabelController.h
//  GitX
//
//  Created by Pieter de Bie on 21-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitHistoryController.h"
#import "PBCommitList.h"
#import "PBGitRef.h"
#import "PBGitCommit.h"
#import "PBRefContextDelegate.h"

@class PBRefMenuItem;

@interface PBRefController : NSObject <PBRefContextDelegate> {
	IBOutlet __unsafe_unretained PBGitHistoryController *historyController;
	IBOutlet NSArrayController *commitController;
	IBOutlet PBCommitList *commitList;

	IBOutlet NSPopUpButton *branchPopUp;
}

- (void) fetchRemote:(PBRefMenuItem *)sender;
- (void) pullRemote:(PBRefMenuItem *)sender;
- (void) pushUpdatesToRemote:(PBRefMenuItem *)sender;
- (void) pushDefaultRemoteForRef:(PBRefMenuItem *)sender;
- (void) pushToRemote:(PBRefMenuItem *)sender;
- (void) showConfirmPushRefSheet:(PBGitRef *)ref remote:(PBGitRef *)remoteRef;

- (void) checkout:(PBRefMenuItem *)sender;
- (void) merge:(PBRefMenuItem *)sender;
- (void) cherryPick:(PBRefMenuItem *)sender;
- (void) rebaseHeadBranch:(PBRefMenuItem *)sender;
- (void) createBranch:(PBRefMenuItem *)sender;
- (void) copySHA:(PBRefMenuItem *)sender;
- (void) copyShortSHA:(PBRefMenuItem *)sender;
- (void) copyPatch:(PBRefMenuItem *)sender;
- (void) diffWithHEAD:(PBRefMenuItem *)sender;
- (void) createTag:(PBRefMenuItem *)sender;
- (void) showTagInfoSheet:(PBRefMenuItem *)sender;

- (NSArray *) menuItemsForRef:(PBGitRef *)ref;
- (NSArray *) menuItemsForCommit:(PBGitCommit *)commit;
- (NSArray *)menuItemsForRow:(NSInteger)rowIndex;


@end
