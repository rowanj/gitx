//
//  PBNSURLPathUserDefaultsTransfomer.m
//  GitX
//
//  Created by Christian Jacobsen on 28/09/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBNSURLPathUserDefaultsTransfomer.h"

/*
 This ValueTransformer is used to store NSURLs in the user defaults system
 as strings, without a host part. It is assumed that the path is an absolute
 path in the local filesystem.
*/

@implementation PBNSURLPathUserDefaultsTransfomer

+ (Class)transformedValueClass {
	return [NSURL class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)transformedValue:(id)value {
	if(value == nil)
	{
		return nil;
	}

	return [NSURL URLWithString:value
				  relativeToURL:[NSURL URLWithString:@"file://localhost/"]];
}

- (id)reverseTransformedValue:(id)value {
	if(value == nil)
	{
		return nil;
	}

	return [value path];
}

@end
