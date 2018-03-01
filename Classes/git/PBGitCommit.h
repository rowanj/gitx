//
//  PBGitCommit.h
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRefish.h" // for @protocol PBGitRefish

@class PBGitRepository;
@class PBGitTree;
@class PBGitRef;
@class PBGraphCellInfo;

extern NSString * const kGitXCommitType;


@interface PBGitCommit : NSObject <PBGitRefish>

@property (nonatomic, weak, readonly) PBGitRepository* repository;

@property (nonatomic, strong, readonly) GTCommit *gtCommit;
@property (nonatomic, strong, readonly) GTOID *OID;

@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSString *subject;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, strong, readonly) NSString *author;
@property (nonatomic, strong, readonly) NSString *authorEmail;
@property (nonatomic, strong, readonly) NSString *authorDate;
@property (nonatomic, strong, readonly) NSString *committer;
@property (nonatomic, strong, readonly) NSString *committerEmail;
@property (nonatomic, strong, readonly) NSString *committerDate;
@property (nonatomic, strong, readonly) NSString *details;
@property (nonatomic, strong, readonly) NSString *patch;
@property (nonatomic, strong, readonly) NSString *SHA;
@property (nonatomic, strong, readonly) NSString *SVNRevision;

@property (nonatomic, copy, readonly) NSArray <GTOID *> *parents;
@property  NSMutableArray* refs;

@property (nonatomic, strong) PBGraphCellInfo *lineInfo;

@property (nonatomic, readonly) PBGitTree* tree;
@property (readonly) NSArray* treeContents;


- (id)initWithRepository:(PBGitRepository *)repo andCommit:(GTCommit *)gtCommit;

- (void) addRef:(PBGitRef *)ref;
- (void) removeRef:(id)ref;
- (BOOL) hasRef:(PBGitRef *)ref;

- (NSString *)SHA;
- (BOOL) isOnSameBranchAs:(PBGitCommit *)other;
- (BOOL) isOnHeadBranch;

// <PBGitRefish>
- (NSString *) refishName;
- (NSString *) shortName;
- (NSString *) refishType;

@end
