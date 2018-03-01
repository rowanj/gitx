//
//  PBTerminalUtil.m
//  GitX
//
//  Created by Sven on 07.08.16.
//

#import "PBTerminalUtil.h"
#import "Terminal.h"

@implementation PBTerminalUtil

+ (NSString *) initialCommand:(NSURL *)workingDirectory {
	return [NSString stringWithFormat:@"cd \"%@\"; clear; echo '# Opened by GitX'; ",
			workingDirectory.path];
}

+ (void) runCommand:(NSString *)command inDirectory:(NSURL *)directory {
	NSString * initialCommand = [self initialCommand:directory];
	NSString * fullCommand = [initialCommand stringByAppendingString:command];
	
	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier: @"com.apple.Terminal"];
	[term doScript:fullCommand in: nil];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[term activate];
	});
}

@end