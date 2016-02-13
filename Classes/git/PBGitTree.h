//
//  PBGitTree.h
//  GitTest
//
//  Created by Pieter de Bie on 15-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRepository;

@interface PBGitTree : NSObject {
	long long _fileSize;

	NSString* sha;
	NSString* path;
	NSArray* children;
	BOOL leaf;

	NSString* localFileName;
	NSDate* localMtime;
}

+ (PBGitTree*) rootForCommit: (id) commit;
+ (PBGitTree*) treeForTree: (PBGitTree*) tree andPath: (NSString*) path;
- (void) saveToFolder: (NSString *) directory;
- (NSString *)textContents;
- (NSString *)blame;
- (NSString *) log:(NSString *)format;

- (NSString*) tmpFileNameForContents;
- (long long)fileSize;

@property(copy) NSString* sha;
@property(copy) NSString* path;
@property(assign) BOOL leaf;
@property(nonatomic, weak) PBGitRepository* repository;
@property(nonatomic, weak) PBGitTree* parent;

@property(readonly) NSArray* children;
@property(readonly) NSString* fullPath;
@property(readonly) NSString* contents;

@end
