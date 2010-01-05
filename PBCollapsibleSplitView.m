//
//  PBCollapsibleSplitView.m
//  GitX
//
//  Created by Johannes Gilger on 6/21/09.
//  Copyright 2009 Johannes Gilger. All rights reserved.
//

#import "PBCollapsibleSplitView.h"

@implementation PBCollapsibleSplitView
@synthesize topViewMin, bottomViewMin;

- (void)setTopMin:(CGFloat)topMin andBottomMin:(CGFloat)bottomMin {
	topViewMin = topMin;
	bottomViewMin = bottomMin;
}

- (void)uncollapse {
	for (NSView *subview in [self subviews]) {
		if([self isSubviewCollapsed:subview]) {
			[self setPosition:[self frame].size.height / 3 ofDividerAtIndex:0];
			[self adjustSubviews];
		}
	}
}

- (void)collapseSubview:(NSInteger)index {
	// Already collapsed, just uncollapse
	if ([self isSubviewCollapsed:[[self subviews] objectAtIndex:index]]) {
		[self setPosition:splitterPosition ofDividerAtIndex:0];
		return;
	}

	// Store splitterposition if the other view isn't collapsed
	if (![self isSubviewCollapsed:[[self subviews] objectAtIndex:(index + 1) % 2]])
		splitterPosition = [[[self subviews] objectAtIndex:0] frame].size.height;

	if (index == 0) // Top view
		[self setPosition:0.0 ofDividerAtIndex:0];
	else // Bottom view
		[self setPosition:[self frame].size.height ofDividerAtIndex:0];
}

- (void)keyDown:(NSEvent *)event {
	if (!([event modifierFlags] & NSShiftKeyMask && [event modifierFlags] & NSCommandKeyMask))
		return [super keyDown:event];

	if ([event keyCode] == 0x07E) {		// Up-Key
		[self collapseSubview:0];
		[[self window] makeFirstResponder:[[self subviews] objectAtIndex:1]];
	} else if ([event keyCode] == 0x07D) {	// Down-Key
		[self collapseSubview:1];
		[[self window] makeFirstResponder:[[self subviews] objectAtIndex:0]];
	}
}
@end
