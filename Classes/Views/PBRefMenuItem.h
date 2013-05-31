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
	id <PBGitRefish> refish;
}

@property  id <PBGitRefish> refish;

+ (PBRefMenuItem *) separatorItem;
+ (NSArray *) defaultMenuItemsForRef:(PBGitRef *)ref inRepository:(PBGitRepository *)repo target:(id)target;
+ (NSArray *) defaultMenuItemsForCommit:(PBGitCommit *)commit target:(id)target;

@end
