//
//  PBGitSVTagItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVTagItem.h"
#import "PBGitRevSpecifier.h"

@implementation PBGitSVTagItem


+ (id)tagItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitSVTagItem *item = [self itemWithTitle:[[revSpecifier description] lastPathComponent]];
	item.revSpecifier = revSpecifier;
	
	return item;
}

- (NSString*) iconName
{
    return @"TagTemplate";
}

@end
