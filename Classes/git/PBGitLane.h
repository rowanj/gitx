//
//  PBGitLane.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#include <git2/oid.h>

class PBGitLane {
	static int s_colorIndex;

	git_oid d_sha;
	int d_index;

public:

	PBGitLane(git_oid *sha)
	{
		d_index = s_colorIndex++;
		d_sha = *sha;
	}

	PBGitLane(NSString *sha)
	{
		git_oid_fromstr(&d_sha, [sha UTF8String]);
		d_index = s_colorIndex++;
	}
	
	PBGitLane()
	{
		d_index = s_colorIndex++;
	}
	
	bool isCommit(git_oid sha) const
	{
		return !git_oid_cmp(&d_sha, &sha);
	}
	
	void setSha(git_oid sha);
	
	git_oid const *sha() const
	{
		return &d_sha;
	}
	
	int index() const;

	static void resetColors();
};