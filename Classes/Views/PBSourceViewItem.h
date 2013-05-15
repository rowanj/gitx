//
//  PBSourceViewItem.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRevSpecifier;
@class PBGitRef;

@interface PBSourceViewItem : NSObject {
    NSMutableOrderedSet *childrenSet;
	NSArray *children;

	NSString *title;
	PBGitRevSpecifier *revSpecifier;

	BOOL isGroupItem;
	BOOL isUncollapsible;
}

+ (id)groupItemWithTitle:(NSString *)title;
+ (id)itemWithRevSpec:(PBGitRevSpecifier *)revSpecifier;
+ (id)itemWithTitle:(NSString *)title;

- (void)addChild:(PBSourceViewItem *)child;
- (void)removeChild:(PBSourceViewItem *)child;

// This adds the ref to the path, which should match the item's title,
// so "refs/heads/pu/pb/sidebar" would have the path [@"pu", @"pb", @"sidebare"]
// to the 'local' branch thing
- (void)addRev:(PBGitRevSpecifier *)revSpecifier toPath:(NSArray *)path;
- (PBSourceViewItem *)findRev:(PBGitRevSpecifier *)rev;

- (PBGitRef *) ref;

@property NSString *title;
@property(readonly) NSArray *children;
@property(assign) BOOL isGroupItem, isUncollapsible;
@property PBGitRevSpecifier *revSpecifier;
@property (assign)PBSourceViewItem *parent;
@property(readonly) NSImage *icon;
@end
