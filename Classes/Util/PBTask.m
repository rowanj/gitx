//
//  PBTask.m
//  GitX
//
//  Created by Etienne on 22/02/2017.
//
//

#import "PBTask.h"

NSString *const PBTaskErrorDomain = @"PBTaskErrorDomain";
NSString *const PBTaskUnderlyingExceptionKey = @"PBTaskUnderlyingExceptionKey";
NSString *const PBTaskTerminationStatusKey = @"PBTaskTerminationStatusKey";
NSString *const PBTaskTerminationOutputKey = @"PBTaskTerminationOutputKey";

const BOOL PBTaskDebugEnable = NO;

#define PBTaskLog(...) \
do { \
	if (PBTaskDebugEnable) NSLog(__VA_ARGS__); \
} while (0)

@interface PBTask ()

@property (retain) NSTask *task;
@property (retain) NSMutableData *standardOutputData;

@end

@implementation PBTask

+ (instancetype)taskWithLaunchPath:(NSString *)launchPath arguments:(NSArray *)arguments inDirectory:(NSString *)directory {
	return [[self alloc] initWithLaunchPath:launchPath arguments:arguments inDirectory:directory];
}

- (instancetype)initWithLaunchPath:(NSString *)launchPath arguments:(NSArray *)args inDirectory:(NSString *)directory
{
	self = [super init];
	if (!self) return nil;

	_task = [[NSTask alloc] init];
	[_task setLaunchPath:launchPath];
	[_task setArguments:args];

	// Prepare ourselves a nicer environment
	NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
	[env removeObjectsForKeys:@[
								@"DYLD_INSERT_LIBRARIES", @"DYLD_LIBRARY_PATH",
								@"MallocGuardEdges", @"MallocNanoZone", @"MallocScribble", @"MallocStackLogging", @"MallocStackLoggingNoCompact",
								@"NSZombieEnabled"]
	 ];
	if (self.additionalEnvironment) {
		[env addEntriesFromDictionary:self.additionalEnvironment];
	}
	[_task setEnvironment:env];

	if (directory)
		[_task setCurrentDirectoryPath:directory];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Show Debug Messages"])
		NSLog(@"Starting command `%@ %@` in dir %@", launchPath, [args componentsJoinedByString:@" "], directory);
#ifdef CLI
	NSLog(@"Starting command `%@ %@` in dir %@", launchPath, [args componentsJoinedByString:@" "], directory);
#endif

	NSPipe *pipe = [NSPipe pipe];
	[_task setStandardOutput:pipe];
	[_task setStandardError:pipe];

	_standardOutputData = [NSMutableData data];
	__weak PBTask *weakSelf = self;
	pipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
		PBTaskLog(@"task %p: can read %d", weakSelf, handle.fileDescriptor);

		NSData *data = handle.availableData;
		if (data.length) {
			@synchronized (weakSelf) {
				[(NSMutableData *)weakSelf.standardOutputData appendData:data];
			}
		} else {
			PBTaskLog(@"task %p: EOF, closing %d", weakSelf, handle.fileDescriptor);
			[handle closeFile];
		}
	};

	PBTaskLog(@"task %p: init", self);

	return self;
}

- (void)dealloc {
	PBTaskLog(@"task %p: dealloc", self);
}


- (void)performTaskOnQueue:(dispatch_queue_t)queue terminationHandler:(void (^)(NSError * _Nullable))terminationHandler {
	NSParameterAssert(terminationHandler != nil);

	__weak PBTask *weakSelf = self;
	self.task.terminationHandler = ^(NSTask *task) {
		NSError *error = nil;
		if (task.terminationReason == NSTaskTerminationReasonUncaughtSignal) {
			PBTaskLog(@"task %p: caught signal", weakSelf);

			NSString *desc = @"Task killed";
			NSArray *taskArguments = [@[task.launchPath] arrayByAddingObjectsFromArray:task.arguments];
			NSString *failureReason = [NSString stringWithFormat:@"The task \"%@\" caught a termination signal", [taskArguments componentsJoinedByString:@" "]];
			NSDictionary *userInfo = @{
									   NSLocalizedDescriptionKey: desc,
									   NSLocalizedFailureReasonErrorKey: failureReason,
									   };
			error = [NSError errorWithDomain:PBTaskErrorDomain code:PBTaskCaughtSignalError userInfo:userInfo];

		} else if (task.terminationReason == NSTaskTerminationReasonExit && task.terminationStatus != 0) {
			// Since we're on an error path, grab the output now and stash it in the returned error

			PBTaskLog(@"task %p: exit != 0", weakSelf);

			NSString *outputString = [[NSString alloc] initWithData:weakSelf.standardOutputData encoding:NSUTF8StringEncoding];
			weakSelf.standardOutputData = nil;

			NSString *desc = @"Task exited unsuccessfully";
			NSArray *taskArguments = [@[task.launchPath] arrayByAddingObjectsFromArray:task.arguments];
			NSString *failureReason = [NSString stringWithFormat:@"The task \"%@\" returned a non-zero return code", [taskArguments componentsJoinedByString:@" "]];
			NSDictionary *userInfo = @{
									   NSLocalizedDescriptionKey: desc,
									   NSLocalizedFailureReasonErrorKey: failureReason,
									   PBTaskTerminationStatusKey: @(task.terminationStatus),
									   PBTaskTerminationOutputKey: outputString,
									   };
			error = [NSError errorWithDomain:PBTaskErrorDomain code:PBTaskNonZeroExitCodeError userInfo:userInfo];
		} else {
			PBTaskLog(@"task %p: exit success", weakSelf);
		}

		dispatch_async(queue, ^{
			terminationHandler(error);
		});
	};

	if (self.standardInputData) {
		NSPipe *inputPipe = [NSPipe pipe];

		self.task.standardInput = inputPipe;

		inputPipe.fileHandleForWriting.writeabilityHandler = ^(NSFileHandle *handle) {
			PBTaskLog(@"task %p: can write %d", weakSelf, handle.fileDescriptor);

			[handle writeData:weakSelf.standardInputData];
			[handle closeFile];
		};
	}

	@try {
		PBTaskLog(@"task %p: launching", self);
		[self.task launch];
	}
	@catch (NSException *exception) {
		NSString *desc = @"Exception raised while launching task";
		NSString *failureReason = [NSString stringWithFormat:@"The task \"%@\" failed to launch", self.task.launchPath];
		NSDictionary *info = @{
							   NSLocalizedDescriptionKey: desc,
							   NSLocalizedFailureReasonErrorKey: failureReason,
							   PBTaskUnderlyingExceptionKey: exception,
							   };
		NSError *error = [NSError errorWithDomain:PBTaskErrorDomain
											 code:PBTaskLaunchError
										 userInfo:info];

		dispatch_async(queue, ^{
			terminationHandler(error);
		});
	}
}

- (void)performTaskOnQueue:(dispatch_queue_t)queue completionHandler:(void (^)(NSData *readData, NSError *error))completionHandler {
	[self performTaskOnQueue:queue terminationHandler:^(NSError *error) {
		if (error) {
			completionHandler(nil, error);
			return;
		}

		@synchronized (self) {
			PBTaskLog(@"task %p: completed, removing read handler", self);
			[self.task.standardOutput fileHandleForReading].readabilityHandler = nil;
		}

		completionHandler(self.standardOutputData, nil);
	}];
}

- (BOOL)launchTask:(NSError **)error {
	dispatch_semaphore_t sem = dispatch_semaphore_create(0);

	__block NSError *taskError = nil;
	
	[self performTaskOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
		   completionHandler:^(NSData *readData, NSError *error) {

		taskError = error;

		dispatch_semaphore_signal(sem);
	}];

	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
	PBTaskLog(@"task %p: waiting for completion", self);
	if (dispatch_semaphore_wait(sem, timeout) != 0) {
		// Timeout !
		// Unset the termination handler before calling, so we don't trigger it
		self.task.terminationHandler = nil;
		[self terminate];

		if (error) {
			NSString *desc = @"Timeout while running task";
			NSArray *taskArguments = [@[self.task.launchPath] arrayByAddingObjectsFromArray:self.task.arguments];
			NSString *failureReason = [NSString stringWithFormat:@"The task \"%@\" failed to complete before its timeout", taskArguments];
			NSDictionary *userInfo = @{
									   NSLocalizedDescriptionKey: desc,
									   NSLocalizedFailureReasonErrorKey: failureReason,
									   };
			*error = [NSError errorWithDomain:PBTaskErrorDomain code:PBTaskTimeoutError userInfo:userInfo];
		}

		return NO;
	}

	if (error) *error = taskError;
	return (taskError == nil);
}

- (void)terminate {
	[self.task terminate];
}

- (NSString *)description {
	NSArray *taskArguments = [@[self.task.launchPath] arrayByAddingObjectsFromArray:self.task.arguments];
	return [NSString stringWithFormat:@"<%@ %p command: %@ stdin: %@>", NSStringFromClass([self class]), self,
			[taskArguments componentsJoinedByString:@" "],
			(self.standardInputData ? @"YES" : @"NO")
			];
}

@end

@implementation PBTask (PBBellsAndWhistles)

+ (NSString *)outputForCommand:(NSString *)launchPath arguments:(NSArray *)arguments error:(NSError **)error {
	return [self outputForCommand:launchPath arguments:arguments inDirectory:nil error:error];
}

+ (NSString *)outputForCommand:(NSString *)launchPath arguments:(NSArray *)arguments inDirectory:(NSString *)directory error:(NSError **)error {
	PBTask *task = [self taskWithLaunchPath:launchPath arguments:arguments inDirectory:directory];
	BOOL success = [task launchTask:error];
	if (!success) return nil;

	return task.standardOutputString;
}

+ (void)launchTask:(NSString *)launchPath arguments:(NSArray *)arguments inDirectory:(NSString *)directory completionHandler:(void (^)(NSData *readData, NSError *error))completionHandler {
	PBTask *task = [self taskWithLaunchPath:launchPath arguments:arguments inDirectory:directory];
	[task performTaskWithCompletionHandler:completionHandler];
}

- (NSString *)standardOutputString {
	return [[NSString alloc] initWithData:self.standardOutputData encoding:NSUTF8StringEncoding];
}

@end

@implementation PBTask (PBMainQueuePerform)

- (void)performTaskWithTerminationHandler:(void (^)(NSError *error))terminationHandler {
	[self performTaskOnQueue:dispatch_get_main_queue() terminationHandler:terminationHandler];
}

- (void)performTaskWithCompletionHandler:(void (^)(NSData * __nullable readData, NSError * __nullable error))completionHandler {
	[self performTaskOnQueue:dispatch_get_main_queue() completionHandler:completionHandler];
}

@end
