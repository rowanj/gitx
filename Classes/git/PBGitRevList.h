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

@interface PBGitRevList : NSObject

@property (nonatomic, assign) BOOL isParsing;
@property (nonatomic, strong) NSMutableArray *commits;

- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph;
- (void) loadRevisons;
- (void)cancel;

@end
