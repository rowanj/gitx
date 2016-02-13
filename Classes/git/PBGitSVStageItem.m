//
//  PBGitSVStageItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVStageItem.h"


@implementation PBGitSVStageItem


+ (id) stageItem
{
	PBGitSVStageItem *item = [self itemWithTitle:@"Stage"];
	
	return item;
}


- (NSString*) iconName
{
    return @"StageTemplate";
}

@end
