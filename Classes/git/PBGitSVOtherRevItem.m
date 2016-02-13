//
//  PBGitSVOtherRevItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVOtherRevItem.h"
#import "PBGitRevSpecifier.h"


@implementation PBGitSVOtherRevItem


+ (id)otherItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitSVOtherRevItem *item = [self itemWithTitle:[revSpecifier title]];
	item.revSpecifier = revSpecifier;
	
	return item;
}

- (NSString*) iconName
{
    return @"BranchTemplate";
}

@end
