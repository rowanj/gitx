//
//  PBGitSVRemoteItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVRemoteItem.h"
#import "PBGitRef.h"


@implementation PBGitSVRemoteItem


+ (id)remoteItemWithTitle:(NSString *)title
{
	PBGitSVRemoteItem *item = [self itemWithTitle:title];
	
	return item;
}

- (NSString*) iconName
{
    return @"RemoteTemplate";
}

- (PBGitRef *) ref
{
	return [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:self.title]];
}

@end
