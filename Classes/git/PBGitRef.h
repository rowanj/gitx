//
//  PBGitRef.h
//  GitX
//
//  Created by Pieter de Bie on 06-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRefish.h"

extern NSString * const kGitXTagType;
extern NSString * const kGitXBranchType;
extern NSString * const kGitXRemoteType;
extern NSString * const kGitXRemoteBranchType;
extern NSString * const kGitXStashType;

extern NSString * const kGitXTagRefPrefix;
extern NSString * const kGitXBranchRefPrefix;
extern NSString * const kGitXRemoteRefPrefix;
extern NSString * const kGitXStashRefPrefix;


@interface PBGitRef : NSObject <PBGitRefish>

// <PBGitRefish>
- (NSString *) refishName;
- (NSString *) shortName;
- (NSString *) refishType;

- (NSString *) tagName;
- (NSString *) branchName;
- (NSString *) remoteName;
- (NSString *) remoteBranchName;

- (NSString *) type;
- (BOOL) isBranch;
- (BOOL) isTag;
- (BOOL) isRemote;
- (BOOL) isRemoteBranch;
- (BOOL) isStash;

- (PBGitRef *) remoteRef;

- (BOOL) isEqualToRef:(PBGitRef *)otherRef;

+ (PBGitRef*) refFromString: (NSString*) s;
- (PBGitRef*) initWithString: (NSString*) s;

@property(nonatomic, strong, readonly) NSString* ref;

@end
