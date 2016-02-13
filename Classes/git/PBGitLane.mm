//
//  PBGitLane.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitLane.h"

int PBGitLane::index() const
{
	return d_index;
}

void PBGitLane::setSha(const git_oid *sha)
{
	d_sha = *sha;
}
