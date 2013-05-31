//
//  PBGitRepositoryWatcherEventPath.h
//  GitX
//
//  Created by Pieter de Bie on 9/6/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBGitRepositoryWatcherEventPath : NSObject
{
	NSString *path;
	FSEventStreamEventFlags flag;
}

@property  NSString *path;
@property (assign) FSEventStreamEventFlags flag;
@end
