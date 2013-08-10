//
//  PBGitRepositoryWatcher.m
//  GitX
//
//  Created by Dave Grijalva on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import <CoreServices/CoreServices.h>
#import "PBGitRepositoryWatcher.h"
#import "PBEasyPipe.h"
#import "PBGitDefaults.h"
#import "PBGitRepositoryWatcherEventPath.h"

#import <ObjectiveGit/ObjectiveGit.h>

NSString *PBGitRepositoryEventNotification = @"PBGitRepositoryModifiedNotification";
NSString *kPBGitRepositoryEventTypeUserInfoKey = @"kPBGitRepositoryEventTypeUserInfoKey";
NSString *kPBGitRepositoryEventPathsUserInfoKey = @"kPBGitRepositoryEventPathsUserInfoKey";

@interface PBGitRepositoryWatcher ()
- (void) _handleEventCallback:(NSArray *)eventPaths;
@end

void PBGitRepositoryWatcherCallback(ConstFSEventStreamRef streamRef,
									void *clientCallBackInfo,
									size_t numEvents,
									void *_eventPaths,
									const FSEventStreamEventFlags eventFlags[],
									const FSEventStreamEventId eventIds[]){
    PBGitRepositoryWatcher *watcher = (__bridge PBGitRepositoryWatcher*)clientCallBackInfo;
	NSMutableArray *changePaths = [[NSMutableArray alloc] init];
	NSArray *eventPaths = (__bridge NSArray*)_eventPaths;
	for (int i = 0; i < numEvents; ++i) {
//		NSLog(@"FSEvent Watcher: %@ Change %llu in %s, flags %lu", watcher, eventIds[i], paths[i], eventFlags[i]);
		NSString *path = [eventPaths objectAtIndex:i];
		if ([path hasSuffix:@".lock"]) {
			continue;
		}
		PBGitRepositoryWatcherEventPath *ep = [[PBGitRepositoryWatcherEventPath alloc] init];
		ep.path = path;
		ep.flag = eventFlags[i];
		[changePaths addObject:ep];
		
	}
	if (changePaths.count) {
		[watcher _handleEventCallback:changePaths];
	}
}

@implementation PBGitRepositoryWatcher

@synthesize repository;

- (id) initWithRepository:(PBGitRepository *)theRepository {
    self = [super init];
    if (!self)
        return nil;

	repository = theRepository;
	FSEventStreamContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};

	NSString *path = [repository.gitURL path];
	NSArray *paths = [NSArray arrayWithObject: path];

	// Create and activate event stream
	eventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &context, 
									  (__bridge CFArrayRef)paths,
									  kFSEventStreamEventIdSinceNow, 1.0,
									  kFSEventStreamCreateFlagUseCFTypes |
									  kFSEventStreamCreateFlagIgnoreSelf |
									  kFSEventStreamCreateFlagFileEvents);
	if ([PBGitDefaults useRepositoryWatcher])
		[self start];
	return self;
}

- (NSDate *) _fileModificationDateAtPath:(NSString *)path {
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

- (BOOL) _indexChanged {
	if (self.repository.isBareRepository) {
		return NO;
	}
    NSDate *newTouchDate = [self _fileModificationDateAtPath:[repository.gitURL.path stringByAppendingPathComponent:@"index"]];
	if (![newTouchDate isEqual:indexTouchDate]) {
		indexTouchDate = newTouchDate;
		return YES;
	}

	return NO;
}

- (BOOL) _gitDirectoryChanged {

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

- (void) _handleEventCallback:(NSArray *)eventPaths {
	PBGitRepositoryWatcherEventType event = 0x0;
	
	if ([self _indexChanged])
	{
//		NSLog(@"Watcher found an index change");
		event |= PBGitRepositoryWatcherEventTypeIndex;
	}
	
	NSString* ourRepo_ns = repository.gitURL.path;
	// libgit2 API results for directories end with a '/'
	if (![ourRepo_ns hasSuffix:@"/"])
		ourRepo_ns = [NSString stringWithFormat:@"%@/", ourRepo_ns];
	
    NSMutableArray *paths = [NSMutableArray array];
    
	for (PBGitRepositoryWatcherEventPath *eventPath in eventPaths) {
		// .git dir
		if ([[eventPath.path stringByStandardizingPath] isEqual:[repository.gitURL.path stringByStandardizingPath]]) {
			if ([self _gitDirectoryChanged] || eventPath.flag != kFSEventStreamEventFlagNone) {
				event |= PBGitRepositoryWatcherEventTypeGitDirectory;
                [paths addObject:eventPath.path];
//				NSLog(@"Watcher: git dir change in %@", eventPath.path);
			}
		}

		// subdirs of .git dir
		else if ([eventPath.path rangeOfString:repository.gitURL.path].location != NSNotFound) {
			// ignore changes to lock files
			if ([eventPath.path hasSuffix:@".lock"])
			{
//				NSLog(@"Watcher: ignoring change to lock file: %@", eventPath.path);
				continue;
			}
			event |= PBGitRepositoryWatcherEventTypeGitDirectory;
            [paths addObject:eventPath.path];
//			NSLog(@"Watcher: git dir subdir change in %@", eventPath.path);
		}
	}
	
	// working dir
	NSMutableDictionary* newStatus = [NSMutableDictionary dictionary];
	[self.repository.gtRepo enumerateFileStatusUsingBlock:^(NSURL *fileURL, GTRepositoryFileStatus status, BOOL *stop) {
		if (status != GIT_STATUS_IGNORED)
		{
			NSNumber* nsStatus = [NSNumber numberWithInt:status];
			NSString* nsKey = [fileURL path];
			[newStatus setValue:nsStatus forKey:nsKey];
		}
	}];
	if (lastStatus)
	{
		if ([lastStatus isEqualToDictionary:newStatus])
		{
//			NSLog(@"Watcher: no changes to working copy");
		}
		else
		{
//			NSLog(@"Watcher: changes to working copy");
			event |= PBGitRepositoryWatcherEventTypeWorkingDirectory;
		}
	}
	lastStatus = newStatus;
			
	
	if(event != 0x0){
//		NSLog(@"PBGitRepositoryWatcher firing notification for repository %@ with flag %lu", repository, event);
        NSDictionary *eventInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
                                   [NSNumber numberWithUnsignedInt:event], kPBGitRepositoryEventTypeUserInfoKey,
                                   paths, kPBGitRepositoryEventPathsUserInfoKey,
                                   NULL];
        
		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitRepositoryEventNotification object:repository userInfo:eventInfo];
	}
}

- (void) start {
    if (_running)
		return;

	// set initial state
	[self _gitDirectoryChanged];
	[self _indexChanged];
	ownRef = self; // The callback has no reference to us, so we need to stay alive as long as it may be called
	FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(eventStream);
	_running = YES;
}

- (void) stop {
    if (!_running)
		return;

	FSEventStreamStop(eventStream);
	FSEventStreamUnscheduleFromRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	ownRef = nil; // Now that we can't be called anymore, we can allow ourself to be -dealloc'd
	_running = NO;
}

@end
