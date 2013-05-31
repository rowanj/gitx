//
//  PBGitGradientBarView.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/22/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBGitGradientBarView : NSView {
	NSGradient *gradient;
}

- (void) setTopShade:(float)topShade bottomShade:(float)bottomShade;
- (void) setTopColor:(NSColor *)topShade bottomColor:(NSColor *)bottomColor;

@end
