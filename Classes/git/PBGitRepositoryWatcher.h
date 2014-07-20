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
@class PBGitRepository;

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

typedef void(^PBGitRepositoryWatcherCallbackBlock)(NSArray *changedFiles);

@interface PBGitRepositoryWatcher : NSObject {
    FSEventStreamRef gitDirEventStream;
	FSEventStreamRef workDirEventStream;
	PBGitRepositoryWatcherCallbackBlock gitDirChangedBlock;
	PBGitRepositoryWatcherCallbackBlock workDirChangedBlock;
	NSDate *gitDirTouchDate;
	NSDate *indexTouchDate;

	NSString *gitDir;
	NSString *workDir;

	__strong PBGitRepositoryWatcher* ownRef;
    BOOL _running;
}

@property (readonly, weak) PBGitRepository *repository;

- (id) initWithRepository:(PBGitRepository *)repository;
- (void) start;
- (void) stop;

@end
