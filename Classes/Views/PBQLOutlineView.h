//
//  PBQLOutlineView.h
//  GitX
//
//  Created by Pieter de Bie on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitHistoryController.h"

@interface PBQLOutlineView : NSOutlineView {
	__weak IBOutlet PBGitHistoryController* controller;
}

@end
