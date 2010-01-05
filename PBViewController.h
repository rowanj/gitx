//
//  PBViewController.h
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"
#import "PBGitWindowController.h"

@interface PBViewController : NSViewController {
	__weak PBGitRepository *repository;
	__weak PBGitWindowController *superController;

	IBOutlet NSToolbar *viewToolbar;
}

@property (readonly) __weak PBGitRepository *repository;
@property (readonly) NSToolbar *viewToolbar;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller;
- (void) removeView;
- (void) updateView;
- (NSResponder *)firstResponder;

@end
