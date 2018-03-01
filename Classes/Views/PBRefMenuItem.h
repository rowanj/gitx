//
//  PBRefMenuItem.h
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRef.h"
#import "PBGitCommit.h"

@interface PBRefMenuItem : NSMenuItem {
	NSArray<id<PBGitRefish>> *refishs;
}

@property NSArray<id<PBGitRefish>> *refishs;

+ (PBRefMenuItem *) separatorItem;
+ (NSArray *) defaultMenuItemsForRef:(PBGitRef *)refs inRepository:(PBGitRepository *)repo target:(id)target;
+ (NSArray *) defaultMenuItemsForCommits:(NSArray<PBGitCommit *> *)commits target:(id)target;

@end
