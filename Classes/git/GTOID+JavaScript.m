//
//  GTOID+JavaScript.m
//  GitX
//
//  Created by Sven Weidauer on 18.05.14.
//
//

#import "GTOID+JavaScript.h"

@implementation GTOID (JavaScript)

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}

@end
