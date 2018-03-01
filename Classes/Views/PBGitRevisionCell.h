//
//  PBGitRevisionCell.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitGrapher.h"
#import "PBGraphCellInfo.h"
#import "PBGitHistoryController.h"
#import "PBRefContextDelegate.h"

@interface PBGitRevisionCell : NSActionCell {
	PBGitCommit *objectValue;
	PBGraphCellInfo *cellInfo;
	NSTextFieldCell *textCell;
	__weak IBOutlet PBGitHistoryController *controller;
	__weak IBOutlet id<PBRefContextDelegate> contextMenuDelegate;
}

- (int) indexAtX:(CGFloat)x;
- (NSRect) rectAtIndex:(int)index;
- (void) drawLabelAtIndex:(int)index inRect:(NSRect)rect;

@property (copy) PBGitCommit* objectValue;
@end
