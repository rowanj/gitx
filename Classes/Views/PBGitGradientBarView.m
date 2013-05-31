//
//  PBGitGradientBarView.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/22/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitGradientBarView.h"



@implementation PBGitGradientBarView


- (id) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	
	[self setTopShade:1.0 bottomShade:0.0];
	
	return self;
}


- (void) drawRect:(NSRect)dirtyRect
{
	[gradient drawInRect:[self bounds] angle:90];
}


- (void) setTopColor:(NSColor *)topColor bottomColor:(NSColor *)bottomColor
{
	if (!topColor || !bottomColor)
		return;
	
	gradient = [[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor];
	[self setNeedsDisplay:YES];
}


- (void) setTopShade:(float)topShade bottomShade:(float)bottomShade
{
	NSColor *topColor = [NSColor colorWithCalibratedWhite:topShade alpha:1.0];
	NSColor *bottomColor = [NSColor colorWithCalibratedWhite:bottomShade alpha:1.0];
	[self setTopColor:topColor bottomColor:bottomColor];
}


@end
