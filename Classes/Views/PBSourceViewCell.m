//
//  PBSourceViewCell.m
//  GitX
//
//  Created by Nathan Kinsinger on 1/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewCell.h"
#import "PBGitSidebarController.h"
#import "PBSourceViewBadge.h"




@implementation PBSourceViewCell

@synthesize isCheckedOut;

# pragma mark context menu delegate methods

- (NSMenu *) menuForEvent:(NSEvent *)event inRect:(NSRect)rect ofView:(NSOutlineView *)view
{
	NSPoint point = [view convertPoint:[event locationInWindow] fromView:nil];
	NSInteger row = [view rowAtPoint:point];

	PBGitSidebarController *controller = (PBGitSidebarController*)[view delegate];

	return [controller menuForRow:row];
}


#pragma mark drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)outlineView
{
	if (isCheckedOut) {
		NSImage *checkedOutImage = [PBSourceViewBadge checkedOutBadgeForCell:self];
		NSSize imageSize = [checkedOutImage size];
		NSRect imageFrame;
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, imageSize.width + 3, NSMaxXEdge);
		imageFrame.size = imageSize;

		// center the decal verctically
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

		[checkedOutImage drawInRect:imageFrame
						   fromRect:NSZeroRect
						  operation:NSCompositeSourceOver
						   fraction:1.0f
					 respectFlipped:YES
							  hints:nil];
	}

	[super drawWithFrame:cellFrame inView:outlineView];
}

@end
