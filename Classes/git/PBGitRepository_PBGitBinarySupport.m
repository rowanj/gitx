//
//  PBGitRepository_PBGitBinarySupport.m
//  GitX
//
//  Created by Etienne on 22/02/2017.
//
//

#import "PBGitRepository_PBGitBinarySupport.h"

#import "PBEasyPipe.h"
#import "PBGitBinary.h"
#import "PBTask.h"

@implementation PBGitRepository (PBGitBinarySupport)

- (PBTask *)taskWithArguments:(NSArray *)arguments
{
	NSArray *realArgs = @[[@"--git-dir=" stringByAppendingString:self.gitURL.path]];

	// Prepend a --git-dir argument in case we're running against a bare repository
	realArgs = [realArgs arrayByAddingObjectsFromArray:arguments];

	return [PBTask taskWithLaunchPath:[PBGitBinary path] arguments:realArgs inDirectory:self.workingDirectory];
}

- (BOOL)launchTaskWithArguments:(nullable NSArray *)arguments error:(NSError **)error {
	PBTask *task = [self taskWithArguments:arguments];
	return [task launchTask:error];
}

- (NSString *)outputOfTaskWithArguments:(NSArray *)arguments error:(NSError **)error {
	PBTask *task = [self taskWithArguments:arguments];
	BOOL success = [task launchTask:error];
	if (!success) return nil;

	return [task standardOutputString];
}

@end

@implementation PBGitRepository (PBGitBinarySupportDeprecated)

- (NSFileHandle*) handleForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.gitURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments];
}

- (NSString*) outputForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments];
}

- (NSString*) outputForCommand:(NSString *)str retValue:(int *)ret;
{
	NSArray* arguments = [str componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments retValue: ret];
}

- (NSString*) outputForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.workingDirectory];
}

- (NSString*) outputInWorkdirForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:self.workingDirectory];
}

- (NSString*) outputInWorkdirForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:self.workingDirectory retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.workingDirectory retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments inputString:(NSString *)input retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:self.workingDirectory
							inputString:input
							   retValue: ret];
}

- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input byExtendingEnvironment:(NSDictionary *)dict retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:self.workingDirectory
				 byExtendingEnvironment:dict
							inputString:input
							   retValue: ret];
}
@end
