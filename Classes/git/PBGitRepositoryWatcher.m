//
//  PBGitRepositoryWatcher.m
//  GitX
//
//  Created by Dave Grijalva on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import <CoreServices/CoreServices.h>

#import "PBGitRepositoryWatcher.h"
#import "PBGitRepository.h"
#import "PBEasyPipe.h"
#import "PBGitDefaults.h"
#import "PBGitRepositoryWatcherEventPath.h"

NSString *PBGitRepositoryEventNotification = @"PBGitRepositoryModifiedNotification";
NSString *kPBGitRepositoryEventTypeUserInfoKey = @"kPBGitRepositoryEventTypeUserInfoKey";
NSString *kPBGitRepositoryEventPathsUserInfoKey = @"kPBGitRepositoryEventPathsUserInfoKey";

@interface PBGitRepositoryWatcher ()

@property (nonatomic, strong) NSMutableDictionary *statusCache;

- (void) handleGitDirEventCallback:(NSArray *)eventPaths;
- (void) handleWorkDirEventCallback:(NSArray *)eventPaths;

@end

void PBGitRepositoryWatcherCallback(ConstFSEventStreamRef streamRef,
									void *clientCallBackInfo,
									size_t numEvents,
									void *_eventPaths,
									const FSEventStreamEventFlags eventFlags[],
									const FSEventStreamEventId eventIds[]){
	PBGitRepositoryWatcherCallbackBlock block = (__bridge PBGitRepositoryWatcherCallbackBlock)clientCallBackInfo;
	
	NSMutableArray *changePaths = [[NSMutableArray alloc] init];
	NSArray *eventPaths = (__bridge NSArray*)_eventPaths;
	for (int i = 0; i < numEvents; ++i) {
		NSString *path = [eventPaths objectAtIndex:i];
		PBGitRepositoryWatcherEventPath *ep = [[PBGitRepositoryWatcherEventPath alloc] init];
		ep.path = [path stringByStandardizingPath];
		ep.flag = eventFlags[i];
		[changePaths addObject:ep];

	}
	if (block && changePaths.count) {
		block(changePaths);
	}
}

@implementation PBGitRepositoryWatcher

@synthesize repository;

- (id) initWithRepository:(PBGitRepository *)theRepository {
    self = [super init];
    if (!self) {
        return nil;
	}
	
	__weak PBGitRepositoryWatcher* weakSelf = self;
	repository = theRepository;

	{
		gitDir = [repository.gtRepo.gitDirectoryURL.path stringByStandardizingPath];
		if (!gitDir) {
			return nil;
		}
		gitDirChangedBlock = ^(NSArray *changeEvents){
			NSMutableArray *filteredEvents = [NSMutableArray new];
			for (PBGitRepositoryWatcherEventPath *event in changeEvents) {
				// exclude all changes to .lock files
				if ([event.path hasSuffix:@".lock"]) {
					continue;
				}
				[filteredEvents addObject:event];
			}
			if (filteredEvents.count) {
				[weakSelf handleGitDirEventCallback:filteredEvents];
			}
		};
		FSEventStreamContext gitDirWatcherContext = {0, (__bridge void *)(gitDirChangedBlock), NULL, NULL, NULL};
		gitDirEventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &gitDirWatcherContext,
												(__bridge CFArrayRef)@[gitDir],
												kFSEventStreamEventIdSinceNow, 1.0,
												kFSEventStreamCreateFlagUseCFTypes |
												kFSEventStreamCreateFlagIgnoreSelf |
												kFSEventStreamCreateFlagFileEvents);
		
	}
	{
		workDir = repository.gtRepo.isBare ? nil : [repository.gtRepo.fileURL.path stringByStandardizingPath];
		if (workDir) {
			workDirChangedBlock = ^(NSArray *changeEvents){
				NSMutableArray *filteredEvents = [NSMutableArray new];
				PBGitRepositoryWatcher *watcher = weakSelf;
				if (!watcher) {
					return;
				}
				for (PBGitRepositoryWatcherEventPath *event in changeEvents) {
					// exclude anything under the .git dir
					if ([event.path hasPrefix:watcher->gitDir]) {
						continue;
					}
					[filteredEvents addObject:event];
				}
				if (filteredEvents.count) {
					[watcher handleWorkDirEventCallback:filteredEvents];
				}
			};
			FSEventStreamContext workDirWatcherContext = {0, (__bridge void *)(workDirChangedBlock), NULL, NULL, NULL};
			workDirEventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &workDirWatcherContext,
													 (__bridge CFArrayRef)@[workDir],
													 kFSEventStreamEventIdSinceNow, 1.0,
													 kFSEventStreamCreateFlagUseCFTypes |
													 kFSEventStreamCreateFlagIgnoreSelf |
													 kFSEventStreamCreateFlagFileEvents);
		}
	}


	self.statusCache = [NSMutableDictionary new];
	
	if ([PBGitDefaults useRepositoryWatcher])
		[self start];
	return self;
}

- (NSDate *) fileModificationDateAtPath:(NSString *)path {
	NSError* error;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path
																		   error:&error];
	if (error)
	{
		NSLog(@"Unable to get attributes of \"%@\"", path);
		return nil;
	}
	return [attrs objectForKey:NSFileModificationDate];
}

- (BOOL) indexChanged {
	if (self.repository.isBareRepository) {
		return NO;
	}
	
    NSDate *newTouchDate = [self fileModificationDateAtPath:[gitDir stringByAppendingPathComponent:@"index"]];
	if (![newTouchDate isEqual:indexTouchDate]) {
		indexTouchDate = newTouchDate;
		return YES;
	}

	return NO;
}

- (BOOL) gitDirectoryChanged {

	for (NSURL* fileURL in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:repository.gitURL
														 includingPropertiesForKeys:[NSArray arrayWithObject:NSURLContentModificationDateKey]
																			options:0
						
																			  error:nil])
	{
		BOOL isDirectory = NO;
		[[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDirectory];
		if (isDirectory) 
			continue;

		NSDate* modTime = nil;
		if (![fileURL getResourceValue:&modTime forKey:NSURLContentModificationDateKey error:nil])
			continue;
		
		if (gitDirTouchDate == nil || [modTime compare:gitDirTouchDate] == NSOrderedDescending)
		{
			NSDate* newModTime = [modTime laterDate:gitDirTouchDate];
			
			gitDirTouchDate = newModTime;
			return YES;
		}
	}
    return NO;
}

- (void) handleGitDirEventCallback:(NSArray *)eventPaths
{
	PBGitRepositoryWatcherEventType event = 0x0;
	
	if ([self indexChanged]) {
		event |= PBGitRepositoryWatcherEventTypeIndex;
	}


    NSMutableArray *paths = [NSMutableArray array];
	for (PBGitRepositoryWatcherEventPath *eventPath in eventPaths) {
		// .git dir
		if ([eventPath.path isEqualToString:gitDir]) {
			if ([self gitDirectoryChanged] || eventPath.flag != kFSEventStreamEventFlagNone) {
				event |= PBGitRepositoryWatcherEventTypeGitDirectory;
                [paths addObject:eventPath.path];
			}
		}
		// ignore objects dir  ... ?
		else if ([eventPath.path rangeOfString:[gitDir stringByAppendingPathComponent:@"objects"]].location != NSNotFound) {
			continue;
		}
		// index is already covered
		else if ([eventPath.path rangeOfString:[gitDir stringByAppendingPathComponent:@"index"]].location != NSNotFound) {
			continue;
		}
		// subdirs of .git dir
		else if ([eventPath.path rangeOfString:gitDir].location != NSNotFound) {
			event |= PBGitRepositoryWatcherEventTypeGitDirectory;
            [paths addObject:eventPath.path];
		}
	}
	
	if(event != 0x0){
		NSDictionary *eventInfo = @{kPBGitRepositoryEventTypeUserInfoKey:@(event),
							  kPBGitRepositoryEventPathsUserInfoKey:paths};

		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitRepositoryEventNotification object:repository userInfo:eventInfo];
	}
}

- (void)handleWorkDirEventCallback:(NSArray *)eventPaths
{
	PBGitRepositoryWatcherEventType event = 0x0;

    NSMutableArray *paths = [NSMutableArray array];
	for (PBGitRepositoryWatcherEventPath *eventPath in eventPaths) {
		unsigned int fileStatus = 0;
		if (![eventPath.path hasPrefix:workDir]) {
			continue;
		}
		if ([eventPath.path isEqualToString:workDir]) {
			event |= PBGitRepositoryWatcherEventTypeWorkingDirectory;
			[paths addObject:eventPath.path];
			continue;
		}
		NSString *eventRepoRelativePath = [eventPath.path substringFromIndex:(workDir.length + 1)];
		int ignoreResult = 0;
		int ignoreError = git_status_should_ignore(&ignoreResult, self.repository.gtRepo.git_repository, eventRepoRelativePath.UTF8String);
		if (ignoreError == GIT_OK && ignoreResult) {
			// file is covered by ignore rules
			NSNumber *oldStatus = self.statusCache[eventPath.path];
			if (!oldStatus || [oldStatus isEqualToNumber:@(GIT_STATUS_IGNORED)]) {
				// no cached status or previously ignored - skip this file
				continue;
			}
		}
		int statusError = git_status_file(&fileStatus, self.repository.gtRepo.git_repository, eventRepoRelativePath.UTF8String);
		if (statusError == GIT_OK) {
			// grab the cached status value and update the cache
			NSNumber *oldStatus = self.statusCache[eventPath.path];
			NSNumber *newStatus = @(fileStatus);
			self.statusCache[eventPath.path] = newStatus;

			BOOL addToChanges = NO;
			if (![oldStatus isEqualTo:newStatus]) {
				addToChanges = YES; // status has changed
			}
			if (fileStatus & GIT_STATUS_WT_MODIFIED) {
				addToChanges = YES; // file has changed, and we were already tracking modified
			}
			if (addToChanges) {
				[paths addObject:eventPath.path];
				event |= PBGitRepositoryWatcherEventTypeWorkingDirectory;
			}

		}
	}

	if(event != 0x0){
		NSDictionary *eventInfo = @{kPBGitRepositoryEventTypeUserInfoKey:@(event),
							  kPBGitRepositoryEventPathsUserInfoKey:paths};

		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitRepositoryEventNotification object:repository userInfo:eventInfo];
	}
}

- (void) start {
    if (_running)
		return;

	// set initial state
	[self gitDirectoryChanged];
	[self indexChanged];
	ownRef = self; // The callback has no reference to us, so we need to stay alive as long as it may be called
	FSEventStreamScheduleWithRunLoop(gitDirEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(gitDirEventStream);

	if (workDirEventStream) {
		FSEventStreamScheduleWithRunLoop(workDirEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamStart(workDirEventStream);
	}

	_running = YES;
}

- (void) stop {
    if (!_running)
		return;

	if (workDirEventStream) {
		FSEventStreamStop(workDirEventStream);
		FSEventStreamUnscheduleFromRunLoop(workDirEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
	FSEventStreamStop(gitDirEventStream);
	FSEventStreamUnscheduleFromRunLoop(gitDirEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	ownRef = nil; // Now that we can't be called anymore, we can allow ourself to be -dealloc'd
	_running = NO;
}

@end
