//
//  RoundedRectangle.m
//  GitX
//
//  Created by Pieter de Bie on 24-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "RoundedRectangle.h"


@implementation NSBezierPath (RoundedRectangle)
+ (NSBezierPath *)bezierPathWithRoundedRect: (NSRect) aRect cornerRadius: (double) cRadius
{
	double left = aRect.origin.x, bottom = aRect.origin.y, width = aRect.size.width, height = aRect.size.height;
	
	//now, crop the radius so we don't get weird effects
	double lesserDim = width < height ? width : height;
	if ( cRadius > lesserDim / 2 )
	{
		cRadius = lesserDim / 2;
	}
	
	//these points describe the rectangle as start and stop points of the
	//arcs making up its corners --points c, e, & g are implicit endpoints of arcs
	//and are unnecessary
	NSPoint a = NSMakePoint( 0, cRadius ), b = NSMakePoint( 0, height - cRadius ),
	d = NSMakePoint( width - cRadius, height ), f = NSMakePoint( width, cRadius ),
	h = NSMakePoint( cRadius, 0 );
	
	//these points describe the center points of the corner arcs
	NSPoint cA = NSMakePoint( cRadius, height - cRadius ),
	cB = NSMakePoint( width - cRadius, height - cRadius ),
	cC = NSMakePoint( width - cRadius, cRadius ),
	cD = NSMakePoint( cRadius, cRadius );
	
	//start
	NSBezierPath *bp = [NSBezierPath bezierPath];
	[bp moveToPoint: a ];
	[bp lineToPoint: b ];
	[bp appendBezierPathWithArcWithCenter: cA radius: cRadius startAngle:180 endAngle:90 clockwise: YES];
	[bp lineToPoint: d ];
	[bp appendBezierPathWithArcWithCenter: cB radius: cRadius startAngle:90 endAngle:0 clockwise: YES];
	[bp lineToPoint: f ];
	[bp appendBezierPathWithArcWithCenter: cC radius: cRadius startAngle:0 endAngle:270 clockwise: YES];
	[bp lineToPoint: h ];
	[bp appendBezierPathWithArcWithCenter: cD radius: cRadius startAngle:270 endAngle:180 clockwise: YES];	
	[bp closePath];
	
	//Transform path to rectangle's origin
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy: left yBy: bottom];
	[bp transformUsingAffineTransform: transform];
	
	return bp; //it's already been autoreleased
}
@end
