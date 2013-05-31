//
//  PBNiceSplitView.m
//  GitX
//
//  Created by Pieter de Bie on 31-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBNiceSplitView.h"

static NSImage *bar;
static NSImage *grip;

@implementation PBNiceSplitView

+(void) initialize
{
	NSString *barPath = [[NSBundle mainBundle] pathForResource:@"mainSplitterBar" ofType:@"tiff"];
	bar = [[NSImage alloc] initWithContentsOfFile: barPath];
	[bar setFlipped: YES];

	NSString *gripPath = [[NSBundle mainBundle] pathForResource:@"mainSplitterDimple" ofType:@"tiff"];
	grip = [[NSImage alloc] initWithContentsOfFile: gripPath];
	[grip setFlipped: YES];
}

- (void)drawDividerInRect:(NSRect)aRect
{
	// Draw bar and grip onto the canvas
	NSRect gripRect = aRect;
	gripRect.origin.x = (NSMidX(aRect) - ([grip size].width/2));
	gripRect.size.width = 8;
	
	[self lockFocus];
	[bar drawInRect:aRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[grip drawInRect:gripRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[self unlockFocus];
}

- (CGFloat)dividerThickness
{
	return 10.0;
}

@end
