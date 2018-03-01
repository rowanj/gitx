//
//  PBTask.h
//  GitX
//
//  Created by Etienne on 22/02/2017.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PBTaskErrorDomain;
extern NSString *const PBTaskUnderlyingExceptionKey;
extern NSString *const PBTaskTerminationStatusKey;
extern NSString *const PBTaskTerminationOutputKey;

typedef NS_ENUM(NSUInteger, PBTaskErrorCode) {
	PBTaskLaunchError = 1,
	PBTaskTimeoutError = 2,
	PBTaskCaughtSignalError = 3,
	PBTaskNonZeroExitCodeError = 4,
};

/// PBTask is a wrapper around NSTask that uses blocks to report when the
/// executable exits, and should be used whenever we need to shell out to git.
@interface PBTask : NSObject

///
/// Setup a task for subsequent execution.
///
/// @param launchPath The absolute path to the executable that should be run.
/// @param arguments  The arguments to pass to the executable. Can be nil.
/// @param directory  The directory to use as the executable working directory. Can be nil.
///
+ (instancetype)taskWithLaunchPath:(NSString *)launchPath arguments:(nullable NSArray *)arguments inDirectory:(nullable NSString *)directory;

///
/// Execute a task.
///
/// @param queue			  The queue on which the handler will be called.
/// @param terminationHandler A block that will be called when the executable exits.
///
- (void)performTaskOnQueue:(dispatch_queue_t)queue terminationHandler:(void (^)(NSError * __nullable error))terminationHandler;

///
/// Execute a task, and process its output
///
/// @param queue			 The queue on which the handler will be called.
/// @param completionHandler A block that will be called when the executable exits.
///							 If readData is nil, it means an error occurred.
///
- (void)performTaskOnQueue:(dispatch_queue_t)queue completionHandler:(void (^)(NSData * __nullable readData, NSError * __nullable error))completionHandler;

/// Execute a task synchronously
///
/// This method will block until the task exits, or a timeout occurs (30s by default).
/// @param error     If the command failed to complete, the pointer will be set to
///                  an error object describing the reason
///
/// @return YES if the command execution was successful, no otherwise
///
- (BOOL)launchTask:(NSError **)error;

/// The standard output of the command
@property (readonly, retain) NSData *standardOutputData;
/// Set this if you want to pass data to the command on its standard input
@property (retain) NSData *standardInputData;
@property (retain) NSDictionary *additionalEnvironment;

- (void)terminate;

@end

@interface PBTask (PBMainQueuePerform)

/// Execute a task
///
/// This uses the main queue
///
/// @see performTaskOnQueue:terminationHandler:
- (void)performTaskWithTerminationHandler:(void (^)(NSError * __nullable error))terminationHandler;

/// Execute a task
///
/// This uses the main queue
///
/// @see performTaskOnQueue:completionHandler:
- (void)performTaskWithCompletionHandler:(void (^)(NSData * __nullable readData, NSError * __nullable error))completionHandler;

@end

@interface PBTask (PBBellsAndWhistles)

/// Execute a command, only caring for its output
///
/// @see -[PBTask outputForCommand:arguments:inDirectory:error]
///
+ (nullable NSString *)outputForCommand:(NSString *)launchPath arguments:(nullable NSArray *)arguments error:(NSError **)error;


/// Execute a command, only caring for its output
///
/// @param launchPath The absolute path to the executable that should be run.
/// @param arguments  The arguments to pass to the executable. Can be nil.
/// @param directory  The directory to use as the executable working directory. Can be nil.
///
/// @return The data outputted by the command as a string, nil in case of failure.
/// Hint: We only try to convert from UTF-8 data, so that might fail.
///
+ (nullable NSString *)outputForCommand:(NSString *)launchPath arguments:(nullable NSArray *)arguments inDirectory:(nullable NSString *)directory error:(NSError **)error;

/// Directly launch a task with a completion handler
///
/// @param launchPath The absolute path to the executable that should be run.
/// @param arguments  The arguments to pass to the executable. Can be nil.
/// @param directory  The directory to use as the executable working directory. Can be nil.
/// @param completionHandler A block that will be called when the executable exits.
///							 If readData is nil, it means an error occurred.
///
+ (void)launchTask:(NSString *)launchPath arguments:(nullable NSArray *)arguments inDirectory:(nullable NSString *)directory completionHandler:(void (^)(NSData * __nullable readData, NSError * __nullable error))completionHandler;

/// Return the standard output data as a string
///
/// If the data is not valid UTF-8, nil will be returned.
///
- (nullable NSString *)standardOutputString;
@end

NS_ASSUME_NONNULL_END
