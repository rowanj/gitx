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

	PBGitLane(const git_oid *sha)
	{
		d_sha = *sha;
	}

	PBGitLane(int index, const git_oid *sha)
	: d_index(index)
	{
		git_oid_cpy(&d_sha, sha);
	}
	
	bool isCommit(const git_oid *sha) const
	{
		return !git_oid_cmp(&d_sha, sha);
	}
	
	void setSha(const git_oid *sha);
	
	git_oid const *sha() const
	{
		return &d_sha;
	}
	
	int index() const;
};