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

NS_ASSUME_NONNULL_BEGIN

@class PBGitRepository;

typedef NS_ENUM(NSUInteger, PBGitRepositoryWatcherEventType) {
	PBGitRepositoryWatcherEventTypeNone = (1 << 0),
	PBGitRepositoryWatcherEventTypeGitDirectory = (1 << 1),
	PBGitRepositoryWatcherEventTypeWorkingDirectory = (1 << 2),
	PBGitRepositoryWatcherEventTypeIndex = (1 << 3),
};

extern NSString *PBGitRepositoryEventNotification;
extern NSString *kPBGitRepositoryEventTypeUserInfoKey;
extern NSString *kPBGitRepositoryEventPathsUserInfoKey;

@interface PBGitRepositoryWatcher : NSObject

@property (readonly, weak) PBGitRepository *repository;

- (instancetype) initWithRepository:(PBGitRepository *)repository;
- (void) start;
- (void) stop;

@end

NS_ASSUME_NONNULL_END
