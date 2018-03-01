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
@class PBGitCommit;

@interface PBGitRevList : NSObject

@property (nonatomic, assign, getter=isParsing, readonly) BOOL parsing;
@property (nonatomic, strong) NSMutableArray<PBGitCommit *> *commits;

- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph;
- (void)loadRevisonsWithCompletionBlock:(void(^)(void))completionBlock;
- (void)cancel;

@end
