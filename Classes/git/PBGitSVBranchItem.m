//
//  PBGitSVBranchItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVBranchItem.h"
#import "PBGitRevSpecifier.h"

@implementation PBGitSVBranchItem


+ (id)branchItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitSVBranchItem *item = [self itemWithTitle:[[revSpecifier description] lastPathComponent]];
	item.revSpecifier = revSpecifier;
	
	return item;
}


- (NSString*) iconName
{
    return @"BranchTemplate";
}

@end
