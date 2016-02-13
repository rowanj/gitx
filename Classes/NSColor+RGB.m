//
//  NSColor+RGB.m
//  GitX
//
//  Created by Rowan James on 18/08/13.
//
//

#import "NSColor+RGB.h"

@implementation NSColor (RGB)

+ (NSColor *)colorWithR:(uint8_t)r G:(uint8_t)g B:(uint8_t)b
{
	const CGFloat MAX_RGB = 255.0;
	NSColor *result = [NSColor colorWithCalibratedRed:(r/MAX_RGB) green:(g/MAX_RGB) blue:(b/MAX_RGB) alpha:1];
	return result;
}

@end
