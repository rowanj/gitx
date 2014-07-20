//
//  PBGitLane.h
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class PBGitLane {
	git_oid d_sha;
	int d_index;

public:

	PBGitLane(int index, git_oid *sha) : d_index(index)
	{
		d_sha = *sha;
	}

	PBGitLane(int index, NSString *sha) : d_index(index)
	{
		git_oid_fromstr(&d_sha, [sha UTF8String]);
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
};