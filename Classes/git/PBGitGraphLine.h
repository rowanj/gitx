//
//  PBLine.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

struct PBGitGraphLine
{
	int upper      : 1;
	int from       : 8;
	int to         : 8;
	int colorIndex : 8;
};
