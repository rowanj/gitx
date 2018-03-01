//
//  PBRefContextDelegate.h
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//


@class PBGitRef;
@class PBGitCommit;


@protocol PBRefContextDelegate
- (NSArray *) menuItemsForRef:(PBGitRef *)ref;
- (NSArray *) menuItemsForCommits:(NSArray<PBGitCommit *> *)commits;
- (NSArray *) menuItemsForRow:(NSInteger)rowIndex;
@end
