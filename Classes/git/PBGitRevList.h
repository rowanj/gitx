//
//  PBGitRevList.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRepository;
@class PBGitRevSpecifier;

@interface PBGitRevList : NSObject {
	NSMutableArray *commits;

	__dct_weak PBGitRepository *repository;
	PBGitRevSpecifier *currentRev;
	BOOL isGraphing;

	NSThread *parseThread;
	BOOL isParsing;
	BOOL resetCommits;
}

- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph;
- (void) loadRevisons;
- (void)cancel;

@property  NSMutableArray *commits;
@property (readonly) BOOL isParsing;

@end
