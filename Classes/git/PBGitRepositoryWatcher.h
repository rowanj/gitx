//
//  PBGitHistoryWatcher.h
//  GitX
//
//  Watches a specified path
//
//  Created by Dave Grijalva on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBGitRepository.h"

typedef UInt32 PBGitRepositoryWatcherEventType;
enum {
	PBGitRepositoryWatcherEventTypeNone = 0x00000000,
	PBGitRepositoryWatcherEventTypeGitDirectory = 0x00000001,
	PBGitRepositoryWatcherEventTypeWorkingDirectory = 0x00000002,
	PBGitRepositoryWatcherEventTypeIndex = 0x00000004
};

extern NSString *PBGitRepositoryEventNotification;
extern NSString *kPBGitRepositoryEventTypeUserInfoKey;
extern NSString *kPBGitRepositoryEventPathsUserInfoKey;

@interface PBGitRepositoryWatcher : NSObject {
    FSEventStreamRef eventStream;
	NSDate *gitDirTouchDate;
	NSDate *indexTouchDate;
	__strong PBGitRepositoryWatcher* ownRef;
    BOOL _running;
	NSDictionary* lastStatus;
}

@property (readonly, dct_weak) PBGitRepository *repository;

- (id) initWithRepository:(PBGitRepository *)repository;
- (void) start;
- (void) stop;

@end
