//
//  RJModalRepoSheet.m
//  GitX
//
//  Created by Rowan James on 1/7/12.
//  Copyright (c) 2012 Phere Development Pty. Ltd. All rights reserved.
//

#import "RJModalRepoSheet.h"

#import "PBGitRepository.h"
#import "PBGitWindowController.h"

@implementation RJModalRepoSheet

@synthesize repository;
@synthesize repoWindow;

- (id) initWithWindowNibName:(NSString *)windowNibName forRepo:(PBGitRepository*)repo
{
	self = [super initWithWindowNibName:windowNibName];
	if (!self)
		return nil;

	self.repository = repo;
	self.repoWindow = repo.windowController;
	
	return self;
}

- (void) show
{
	[repoWindow showModalSheet:self];
}

- (void) hide
{
	[repoWindow hideModalSheet:self];
}

@end
