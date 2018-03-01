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
#import "PBGitDefaults.h"

NSString *PBGitRepositoryEventNotification = @"PBGitRepositoryModifiedNotification";
NSString *kPBGitRepositoryEventTypeUserInfoKey = @"kPBGitRepositoryEventTypeUserInfoKey";
NSString *kPBGitRepositoryEventPathsUserInfoKey = @"kPBGitRepositoryEventPathsUserInfoKey";

typedef void (^PBGitRepositoryWatcherCallbackBlock)(NSArray *changedFiles);

/* Small helper class to keep track of events */
@interface PBGitRepositoryWatcherEventPath : NSObject
@property NSString *path;
@property (assign) FSEventStreamEventFlags flag;
@end

@implementation PBGitRepositoryWatcherEventPath
@end

@interface PBGitRepositoryWatcher () {
	FSEventStreamRef eventStream;
	NSDate *gitDirTouchDate;
	NSDate *indexTouchDate;

	BOOL _running;
}

@property (readonly) NSString *gitDir;
@property (readonly) NSString *workDir;

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
	PBGitRepositoryWatcher *watcher = (__bridge PBGitRepositoryWatcher *)clientCallBackInfo;

	NSMutableArray *gitDirEvents = [NSMutableArray array];
	NSMutableArray *workDirEvents = [NSMutableArray array];
	NSArray *eventPaths = (__bridge NSArray*)_eventPaths;
	for (int i = 0; i < numEvents; ++i) {
		NSString *path = [eventPaths objectAtIndex:i];
		PBGitRepositoryWatcherEventPath *ep = [[PBGitRepositoryWatcherEventPath alloc] init];
		ep.path = [path stringByStandardizingPath];
		ep.flag = eventFlags[i];


		if ([ep.path hasPrefix:watcher.gitDir]) {
			// exclude all changes to .lock files
			if ([ep.path hasSuffix:@".lock"]) {
				continue;
			}
			[gitDirEvents addObject:ep];
		} else if ([ep.path hasPrefix:watcher.workDir]) {
			[workDirEvents addObject:ep];
		}
	}

	if (workDirEvents.count) {
		[watcher handleWorkDirEventCallback:workDirEvents];
	}
	if (gitDirEvents.count) {
		[watcher handleGitDirEventCallback:gitDirEvents];
	}
}

@implementation PBGitRepositoryWatcher

- (instancetype) initWithRepository:(PBGitRepository *)theRepository {
	NSParameterAssert(theRepository != nil);

    self = [super init];
    if (!self) {
        return nil;
	}

	_repository = theRepository;
	_statusCache = [NSMutableDictionary new];
	
	if ([PBGitDefaults useRepositoryWatcher])
		[self start];
	return self;
}

- (void)dealloc {
	if (eventStream) {
		FSEventStreamStop(eventStream);
		FSEventStreamInvalidate(eventStream);
		FSEventStreamRelease(eventStream);
	}
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
	
    NSDate *newTouchDate = [self fileModificationDateAtPath:[self.gitDir stringByAppendingPathComponent:@"index"]];
	if (![newTouchDate isEqual:indexTouchDate]) {
		indexTouchDate = newTouchDate;
		return YES;
	}

	return NO;
}

- (BOOL) gitDirectoryChanged {

	NSArray *properties = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey];
	NSArray <NSURL *> *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.repository.gitURL
															 includingPropertiesForKeys:properties
																				options:0
																				  error:nil];
	for (NSURL *fileURL in urls)
	{
		NSNumber *number = nil;
		if (![fileURL getResourceValue:&number forKey:NSURLIsDirectoryKey error:nil] || [number boolValue]) {
			continue;
		}

		NSDate *modTime = nil;
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
		if ([eventPath.path isEqualToString:self.gitDir]) {
			if ([self gitDirectoryChanged] || eventPath.flag != kFSEventStreamEventFlagNone) {
				event |= PBGitRepositoryWatcherEventTypeGitDirectory;
                [paths addObject:eventPath.path];
			}
		}
		// ignore objects dir  ... ?
		else if ([eventPath.path rangeOfString:[self.gitDir stringByAppendingPathComponent:@"objects"]].location != NSNotFound) {
			continue;
		}
		// index is already covered
		else if ([eventPath.path rangeOfString:[self.gitDir stringByAppendingPathComponent:@"index"]].location != NSNotFound) {
			continue;
		}
		// subdirs of .git dir
		else if ([eventPath.path rangeOfString:self.gitDir].location != NSNotFound) {
			event |= PBGitRepositoryWatcherEventTypeGitDirectory;
            [paths addObject:eventPath.path];
		}
	}
	
	if(event != 0x0){
		NSDictionary *eventInfo = @{kPBGitRepositoryEventTypeUserInfoKey:@(event),
							  kPBGitRepositoryEventPathsUserInfoKey:paths};

		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitRepositoryEventNotification object:self.repository userInfo:eventInfo];
	}
}

- (void)handleWorkDirEventCallback:(NSArray *)eventPaths
{
	PBGitRepositoryWatcherEventType event = 0x0;

    NSMutableArray *paths = [NSMutableArray array];
	for (PBGitRepositoryWatcherEventPath *eventPath in eventPaths) {
		unsigned int fileStatus = 0;
		if (![eventPath.path hasPrefix:self.workDir]) {
			continue;
		}
		if ([eventPath.path isEqualToString:self.workDir]) {
			event |= PBGitRepositoryWatcherEventTypeWorkingDirectory;
			[paths addObject:eventPath.path];
			continue;
		}
		NSString *eventRepoRelativePath = [eventPath.path substringFromIndex:(self.workDir.length + 1)];
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
			NSNumber *newStatus = @(fileStatus);
			self.statusCache[eventPath.path] = newStatus;

			[paths addObject:eventPath.path];
			event |= PBGitRepositoryWatcherEventTypeWorkingDirectory;
		}
	}

	if(event != 0x0){
		NSDictionary *eventInfo = @{kPBGitRepositoryEventTypeUserInfoKey:@(event),
							  kPBGitRepositoryEventPathsUserInfoKey:paths};

		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitRepositoryEventNotification object:self.repository userInfo:eventInfo];
	}
}

- (NSString *)gitDir {
	return [self.repository.gtRepo.gitDirectoryURL.path stringByStandardizingPath];
}

- (NSString *)workDir {
	return !self.repository.gtRepo.isBare ? [self.repository.gtRepo.fileURL.path stringByStandardizingPath] : nil;
}

- (void) _initializeStream {
	if (eventStream) return;

	NSMutableArray *array = [NSMutableArray array];
	if (self.gitDir) [array addObject:self.gitDir];
	if (self.workDir) [array addObject:self.workDir];

	if (!array.count) return;

	FSEventStreamContext gitDirWatcherContext = {0, (__bridge void *)(self), NULL, NULL, NULL};
	eventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &gitDirWatcherContext,
											(__bridge CFArrayRef)array,
											kFSEventStreamEventIdSinceNow, 1.0,
											kFSEventStreamCreateFlagUseCFTypes |
											kFSEventStreamCreateFlagIgnoreSelf |
											kFSEventStreamCreateFlagFileEvents);
}

- (void) start {
    if (_running)
		return;

	// set initial state
	[self gitDirectoryChanged];
	[self indexChanged];
	[self _initializeStream];

	if (!eventStream) return;

	FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(eventStream);

	_running = YES;
}

- (void) stop {
    if (!_running)
		return;

	if (eventStream) {
		FSEventStreamStop(eventStream);
		FSEventStreamUnscheduleFromRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}

	_running = NO;
}

@end
