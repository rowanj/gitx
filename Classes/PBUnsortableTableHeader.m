//
//  PBUnsortableTableHeader.m
//  GitX
//
//  Created by Pieter de Bie on 03-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBUnsortableTableHeader.h"


@implementation PBUnsortableTableHeader

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint location = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:[[self window] contentView]];
	NSInteger aColumnIndex = [self columnAtPoint:location];

	// If the user pressed on another column, reset
	if (aColumnIndex != columnIndex)
	{
		clickCount = 1;
		columnIndex = aColumnIndex;
		[super mouseDown:theEvent];
		return;
	}

	// On the third click, reset the sorting and
	// Don't pass on the click
	if (++clickCount == 3)
	{
		clickCount = 0;
		controller.sortDescriptors = [NSArray array];
		[controller rearrangeObjects];
		return;
	}
	[super mouseDown:theEvent];
}
@end
