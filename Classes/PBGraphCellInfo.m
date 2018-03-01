//
//  PBGraphCellInfo.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGraphCellInfo.h"


@implementation PBGraphCellInfo
@synthesize nLines, position, numColumns, sign;

- (id)initWithPosition:(long)p andLines:(struct PBGitGraphLine *)l
{
	position = p;
	lines = l;
	
	return self;
}

- (struct PBGitGraphLine*)lines
{
	return lines;
}

- (void)setLines:(struct PBGitGraphLine *)l
{
	free(lines);
	lines = l;
}

- (NSString *)description { return [self debugDescription]; }

- (NSString *)debugDescription
{
	NSMutableString *desc = [NSMutableString stringWithFormat:@"<%@: %p position: %d numColumns: %d nLines: %d sign: '%c'>",
							 NSStringFromClass([self class]), self, position, numColumns, nLines, sign];
	for (int lineIndex = 0; lineIndex < nLines; lineIndex++) {
		struct PBGitGraphLine line = lines[lineIndex];
		[desc appendString:[NSString stringWithFormat:@"\n\t<upper: %d from: %d to: %d colorIndex: %d>",
							line.upper, line.from, line.to, line.colorIndex]];
	}
	return desc;
}

-(void) dealloc
{
	free(lines);
}

@end
