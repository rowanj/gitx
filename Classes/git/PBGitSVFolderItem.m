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


- (NSImage *) icon
{
	static NSImage *folderImage = nil;
	if (!folderImage) {
		folderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
		[folderImage setSize:NSMakeSize(16,16)];
	}

	return folderImage;
}

@end
