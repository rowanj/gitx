//
//  PBEasyFS.m
//  GitX
//
//  Created by Pieter de Bie on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBEasyFS.h"


@implementation PBEasyFS

+ (NSString*) tmpDirWithPrefix: (NSString*) path
{
	NSString* newName = [NSString stringWithFormat: @"%@%@.XXXXXX", NSTemporaryDirectory(), path];
	char *template = (char*) [newName fileSystemRepresentation];
	template = mkdtemp(template);
	return [NSString stringWithUTF8String:template];
}

@end
