//
//  PBGraphCellInfo.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitGraphLine.h"

@interface PBGraphCellInfo : NSObject
{
	struct PBGitGraphLine *lines;
	long nLines;
	long position;
	long numColumns;
	char sign;	
}

@property struct PBGitGraphLine *lines;
@property(assign) long nLines;
@property(assign) long position;
@property(assign) long numColumns;
@property(assign) char sign;


- (id)initWithPosition:(long)p andLines:(struct PBGitGraphLine *)l;

@end
