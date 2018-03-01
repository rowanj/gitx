//
//  PBIconAndTextCell.m
//  GitX
//
//  Created by Ciarán Walsh on 23/09/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//
// Adopted from http://www.cocoadev.com/index.pl?NSTableViewImagesAndText

#import "PBIconAndTextCell.h"

static const CGFloat kIconSpacing = 4;
static const CGFloat kIconPadding = 3;

@interface PBIconAndTextCell ()

@property(strong) NSImageCell *imageCell;

@end

@implementation PBIconAndTextCell
@dynamic image;
@synthesize imageCell;

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder])) {
		imageCell = [[NSImageCell alloc] init];
	}
	return self;
}

- (NSImage *)image
{
	return imageCell.image;
}

- (void)setImage:(NSImage *)image
{
	imageCell.image = image;
}

- (id)copyWithZone:(NSZone *)zone
{
	PBIconAndTextCell *cell = [super copyWithZone:zone];
	cell.imageCell          = [imageCell copyWithZone:zone];
	return cell;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	NSRect textFrame, imageFrame;
	NSDivideRect (aRect, &imageFrame, &textFrame, kIconSpacing + [imageCell.image size].width, NSMinXEdge);
	[super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if (imageCell.image) {
		NSRect imageFrame = cellFrame;
		imageFrame.size.width = imageCell.image.size.width;
		imageFrame.origin.x += kIconPadding;
		[imageCell drawWithFrame:imageFrame inView:controlView];
		cellFrame.origin.x += imageFrame.size.width + kIconSpacing;
		cellFrame.size.width -= imageFrame.size.width + kIconSpacing;
	}
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (imageCell.image ? [imageCell.image size].width : 0) + kIconSpacing;
	return cellSize;
}

// ===============
// = Hit testing =
// ===============
// Adopted from PhotoSearch Apple sample code

- (NSCellHitResult)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];

	NSRect textFrame, imageFrame;
	NSDivideRect (cellFrame, &imageFrame, &textFrame, kIconSpacing + [imageCell.image size].width, NSMinXEdge);
	if (NSMouseInRect(point, imageFrame, [controlView isFlipped]))
		return NSCellHitContentArea | NSCellHitTrackableArea;

	return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
}

+ (BOOL)prefersTrackingUntilMouseUp
{
	// NSCell returns NO for this by default. If you want to have trackMouse:inRect:ofView:untilMouseUp: always track until the mouse is up, then you MUST return YES. Otherwise, strange things will happen.
	return YES;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag
{
	[self setControlView:controlView];

	NSRect textFrame, imageFrame;
	NSDivideRect (cellFrame, &imageFrame, &textFrame, kIconSpacing + [imageCell.image size].width, NSMinXEdge);
	while ([theEvent type] != NSLeftMouseUp) {
		// This is VERY simple event tracking. We simply check to see if the mouse is in the "i" button or not and dispatch entered/exited mouse events
		NSPoint point = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
		BOOL mouseInButton = NSMouseInRect(point, imageFrame, [controlView isFlipped]);
		if (mouseDownInButton != mouseInButton) {
			mouseDownInButton = mouseInButton;
			[controlView setNeedsDisplayInRect:cellFrame];
		}
		if ([theEvent type] == NSMouseEntered || [theEvent type] == NSMouseExited)
			[NSApp sendEvent:theEvent];
		// Note that we process mouse entered and exited events and dispatch them to properly handle updates
		theEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
	}

	// Another way of implementing the above code would be to keep an NSButtonCell as an ivar, and simply call trackMouse:inRect:ofView:untilMouseUp: on it, if the tracking area was inside of it.
	if (mouseDownInButton) {
		// Send the action, and redisplay
		mouseDownInButton = NO;
		[controlView setNeedsDisplayInRect:cellFrame];
		if (self.action)
			[NSApp sendAction:self.action to:self.target from:self];
	}

	// We return YES since the mouse was released while we were tracking. Not returning YES when you processed the mouse up is an easy way to introduce bugs!
	return YES;
}

@end
