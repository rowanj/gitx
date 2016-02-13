//
//  PBGitSVRemoteBranchItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVRemoteBranchItem.h"
#import "PBGitRevSpecifier.h"

@implementation PBGitSVRemoteBranchItem


+ (id)remoteBranchItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitSVRemoteBranchItem *item = [self itemWithTitle:[[revSpecifier description] lastPathComponent]];
	item.revSpecifier = revSpecifier;
	
	return item;
}

- (NSString*) iconName
{
    return @"RemoteBranchTemplate";
}

@end
