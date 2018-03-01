//
//  PBOpenShallowRepositoryErrorRecoveryAttempter.m
//  GitX
//
//  Created by Sven on 07.08.16.
//

#import "PBOpenShallowRepositoryErrorRecoveryAttempter.h"
#import "PBTerminalUtil.h"


@implementation PBOpenShallowRepositoryErrorRecoveryAttempter

NSURL * workingDirectory;

- (instancetype) initWithURL:(NSURL *)url {
	if (self != nil) {
		workingDirectory = url;
	}
	return self;
}

- (BOOL)attemptRecoveryFromError:(NSError *)error
					 optionIndex:(NSUInteger)recoveryOptionIndex {

	if (recoveryOptionIndex == 1) {
		NSString * unshallowCommand = @"echo 'Please re-open the repository in GitX once unshallowing has finished.'; git fetch --unshallow";
		[PBTerminalUtil runCommand:unshallowCommand inDirectory:workingDirectory];
		return NO;
	}
	return NO;
}

+ (NSArray<NSString*>*) errorDialogButtonNames {
	return @[
	  NSLocalizedString(@"OK", @"OK"),
	  NSLocalizedString(@"Run command in Terminal", @"Button to run unshallow command in Terminal")];
}

@end