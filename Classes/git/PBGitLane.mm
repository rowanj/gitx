//
//  PBGitLane.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitLane.h"
//class PBGitLane {
//	static int s_colorIndex;
//	
//	char d_sha[20];
//	int d_index;
//	
//public:
//	PBGitLane(NSString *sha);
//	
//	bool isCommit(NSString *sha) const;
//	int index(); const;
//	
//	static resetColors();
//};

int PBGitLane::s_colorIndex = 0;

int PBGitLane::index() const
{
	return d_index;
}

void PBGitLane::setSha(git_oid sha)
{
	d_sha = sha;
}

void PBGitLane::resetColors()
{
	s_colorIndex = 0;
}
