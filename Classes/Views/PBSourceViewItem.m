//
//  PBSourceViewItem.m
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PBSourceViewItem.h"
#import "PBSourceViewItems.h"
#import "PBGitRef.h"

@interface PBSourceViewItem ()

@property (nonatomic, strong) NSArray *sortedChildren;

@end

@implementation PBSourceViewItem

@synthesize parent, isGroupItem, revSpecifier, isUncollapsible, isExpanded;
@dynamic icon;

- (id)init
{
	if (!(self = [super init]))
		return nil;

	childrenSet = [[NSMutableOrderedSet alloc] init];
	return self;
}

+ (id)itemWithTitle:(NSString *)title
{
	PBSourceViewItem *item = [[[self class] alloc] init];
	item.title = title;
	return item;
}

+ (id)groupItemWithTitle:(NSString *)title
{
	PBSourceViewItem *item = [self itemWithTitle:[title uppercaseString]];
	item.isGroupItem = YES;
	return item;
}

+ (id)itemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitRef *ref = [revSpecifier ref];

	if ([ref isTag])
		return [PBGitSVTagItem tagItemWithRevSpec:revSpecifier];
	else if ([ref isBranch])
		return [PBGitSVBranchItem branchItemWithRevSpec:revSpecifier];
	else if ([ref isRemoteBranch])
		return [PBGitSVRemoteBranchItem remoteBranchItemWithRevSpec:revSpecifier];

	return [PBGitSVOtherRevItem otherItemWithRevSpec:revSpecifier];
}

- (NSArray *)sortedChildren
{
    if (!self->_sortedChildren) {
        NSArray *newArray = [childrenSet sortedArrayUsingComparator:^NSComparisonResult(PBSourceViewItem *obj1, PBSourceViewItem *obj2) {
            return [obj1.title localizedStandardCompare:obj2.title];
        }];
		self.sortedChildren = newArray;
    }
    return [NSArray arrayWithArray:self->_sortedChildren];
}

- (void)addChild:(PBSourceViewItem *)child
{
	if (!child)
		return;
    
	[childrenSet addObject:child];
    self.sortedChildren = nil;
	child.parent = self;
}

- (void)removeChild:(PBSourceViewItem *)child
{
	if (!child)
		return;

	[childrenSet removeObject:child];
    self.sortedChildren = nil;
	if (!self.isGroupItem && ([childrenSet count] == 0))
		[self.parent removeChild:self];
}

- (void)addRev:(PBGitRevSpecifier *)theRevSpecifier toPath:(NSArray *)path
{
	if ([path count] == 1) {
		PBSourceViewItem *item = [PBSourceViewItem itemWithRevSpec:theRevSpecifier];
		[self addChild:item];
		return;
	}

	NSString *firstTitle = [path objectAtIndex:0];
	PBSourceViewItem *node = nil;
	for (PBSourceViewItem *child in childrenSet)
		if ([child.title isEqualToString:firstTitle])
			node = child;

	if (!node) {
		if ([firstTitle isEqualToString:[[theRevSpecifier ref] remoteName]])
			node = [PBGitSVRemoteItem remoteItemWithTitle:firstTitle];
		else {
			node = [PBGitSVFolderItem folderItemWithTitle:firstTitle];
            node.isExpanded = [[self title] isEqualToString:@"BRANCHES"];
        }
		[self addChild:node];
	}

	[node addRev:theRevSpecifier toPath:[path subarrayWithRange:NSMakeRange(1, [path count] - 1)]];
}

- (PBSourceViewItem *)findRev:(PBGitRevSpecifier *)rev
{
	if ([rev isEqual:revSpecifier])
		return self;

	PBSourceViewItem *item = nil;
	for (PBSourceViewItem *child in childrenSet)
		if ( (item = [child findRev:rev]) != nil )
			return item;

	return nil;
}

- (NSImage *) icon
{
    return [self iconNamed:[self iconName]];
}

- (NSImage *)iconNamed:(NSString*)name
{
    NSImage* iconImage = [NSImage imageNamed:name];
    [iconImage setSize:NSMakeSize(16,16)];
    [iconImage setCacheMode:NSImageCacheAlways];
    return iconImage;
}

- (NSString *)title
{
	if (title)
		return title;
	
	return [[revSpecifier description] lastPathComponent];
}

- (void) setTitle:(NSString *)_title
{
	title = _title;
}

- (NSString *) stringValue
{
	return self.title;
}

- (PBGitRef *) ref
{
	if (self.revSpecifier)
		return [self.revSpecifier ref];

	return nil;
}

@end
