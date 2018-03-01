//
//  PBFileChangesTableView.m
//  GitX
//
//  Created by Pieter de Bie on 09-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBFileChangesTableView.h"
#import "PBGitCommitController.h"

@implementation PBFileChangesTableView

#pragma mark NSTableView overrides

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([self delegate]) {
		NSPoint eventLocation = [self convertPoint:[theEvent locationInWindow] fromView: nil];
		NSInteger rowIndex = [self rowAtPoint:eventLocation];
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:YES];
		return [super menuForEvent:theEvent];
	}

	return nil;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	return NSDragOperationEvery;
}

#pragma mark NSView overrides

-(BOOL)acceptsFirstResponder
{
    return [self numberOfRows] > 0;
}

@end
