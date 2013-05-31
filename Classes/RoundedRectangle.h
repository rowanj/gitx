//
//  RoundedRectangle.h
//  GitX
//
//  Created by Pieter de Bie on 24-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath (RoundedRectangle)

+ (NSBezierPath *)bezierPathWithRoundedRect: (NSRect) aRect cornerRadius: (double) cRadius;

@end
