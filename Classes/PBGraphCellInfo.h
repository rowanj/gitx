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
	int position;
	struct PBGitGraphLine *lines;
	int nLines;
	int numColumns;
	char sign;	
}

@property struct PBGitGraphLine *lines;
@property(assign) int nLines;
@property(assign) int position, numColumns;
@property(assign) char sign;


- (id)initWithPosition:(int) p andLines:(struct PBGitGraphLine *) l;

@end