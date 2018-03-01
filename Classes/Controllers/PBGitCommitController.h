//
//  PBGitCommitController.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitIndex;

@interface PBGitCommitController : PBViewController

- (IBAction) refresh:(id) sender;
- (IBAction) commit:(id) sender;
- (IBAction) forceCommit:(id) sender;
- (IBAction) signOff:(id)sender;

- (PBGitIndex *) index;

@end
