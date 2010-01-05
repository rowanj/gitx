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

@interface PBRefController : NSObject <PBRefContextDelegate> {
	IBOutlet __weak PBGitHistoryController *historyController;
	IBOutlet NSArrayController *commitController;
	IBOutlet PBCommitList *commitList;

	IBOutlet NSWindow *newBranchSheet;
	IBOutlet NSTextField *newBranchName;
	IBOutlet NSTextField *errorMessage;

	IBOutlet NSPopUpButton *branchPopUp;
}

- (IBAction)addRef:(id)sender;
- (IBAction)closeSheet:(id) sender;
- (IBAction)saveSheet:(id) sender;

- (NSArray *) menuItemsForRef:(PBGitRef *)ref commit:(PBGitCommit *)commit;

- (void) changeBranch:(NSMenuItem *)sender;
- (void) selectCurrentBranch;
- (void) updateBranchMenu;

@end
