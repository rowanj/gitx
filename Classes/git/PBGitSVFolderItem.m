//
//  PBGitSVFolderItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVFolderItem.h"


@implementation PBGitSVFolderItem

+ (id)folderItemWithTitle:(NSString *)title
{
	PBGitSVFolderItem *item = [self itemWithTitle:title];
	
	return item;
}

- (NSString*) iconName
{
    return (self.isExpanded) ? @"FolderTemplate" : @"FolderClosedTemplate";
}

@end
