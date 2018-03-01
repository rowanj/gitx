//
//  PBGitBinary.m
//  GitX
//
//  Created by Pieter de Bie on 04-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitBinary.h"
#import "PBTask.h"

@implementation PBGitBinary

static NSString* gitPath = nil;

+ (NSString *)versionForPath:(NSString *)path
{
	if (!path)
		return nil;

	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return nil;

	NSString *version = [PBTask outputForCommand:path arguments:@[@"--version"] error:NULL];

	return [self extractGitVersion:version];
}

+ (NSString *) extractGitVersion:(NSString *)versionString
{
	NSError * error;
	NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:@"git version ([0-9.]+)"
																			options:0
																			  error:&error];
	NSTextCheckingResult * result = [regex firstMatchInString:versionString
													  options:0
														range:NSMakeRange(0, versionString.length)];
	if (result != nil && result.numberOfRanges == 2) {
		return [versionString substringWithRange:[result rangeAtIndex:1]];
	}
	return nil;
}

+ (BOOL) acceptBinary:(NSString *)path
{
	if (!path)
		return NO;

	NSString *version = [self versionForPath:path];
	if (!version)
		return NO;

	int c = [version compare:@"" MIN_GIT_VERSION options:NSNumericSearch];
	if (c == NSOrderedSame || c == NSOrderedDescending) {
		gitPath = path;
		return YES;
	}

	NSLog(@"Found a git binary at %@, but is only version %@", path, version);
	return NO;
}

+ (void) initialize
{
	// Check what we might have in user defaults
	// NOTE: Currently this should NOT have a registered default, or the searching bits below won't work
	gitPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"gitExecutable"];
	if (gitPath.length > 0) {
		if ([self acceptBinary:gitPath])
			return;
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Invalid git path", @"Error message for NSUserDefaults configured path to git binary that does not point to a git binary")
					  	 defaultButton:NSLocalizedString(@"OK", @"OK")
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(
										@"The path „%@“, which is configured as a custom git path in the "
										"preferences window, is not a valid git v" MIN_GIT_VERSION " or higher binary. "
										"Using the default search paths instead.",
										"Informative text for NSUserDefaults configured path to git binary that does not point to a git binary"),
										gitPath]
		runModal];
	}

	// Try to find the path of the Git binary
	char* path = getenv("GIT_PATH");
	if (path && [self acceptBinary:[NSString stringWithUTF8String:path]])
		return;

	// No explicit path.
	
	// Try to find git with "which"
	NSString* whichPath = [PBTask outputForCommand:@"/usr/bin/which" arguments:@[@"git"] error:NULL];
	if ([self acceptBinary:whichPath])
		return;

	// Still no path. Let's try some default locations.
	for (NSString* location in [PBGitBinary searchLocations]) {
		if ([self acceptBinary:location])
			return;
	}
	
	// Lastly, try `xcrun git`
	NSString* xcrunPath = [PBTask outputForCommand:@"/usr/bin/xcrun" arguments:@[@"-f", @"git"] error:NULL];
	if ([self acceptBinary:xcrunPath])
	{
		return;
	}

	NSLog(@"Could not find a git binary higher than version " MIN_GIT_VERSION);
}

+ (NSString *) path;
{
	return gitPath;
}

static NSMutableArray *locations = nil;

+ (NSArray *) searchLocations
{
	if (!locations)
	{
		locations = [[NSMutableArray alloc] initWithObjects:
					 @"/opt/local/bin/git",
					 @"/sw/bin/git",
					 @"/opt/git/bin/git",
					 @"/usr/local/bin/git",
					 @"/usr/local/git/bin/git",
					 nil];
		
		[locations addObject:[@"~/bin/git" stringByExpandingTildeInPath]];
		[locations addObject:@"/usr/bin/git"];
	}
	return locations;
}

+ (NSString *) notFoundError
{
	NSString * searchPathsString = [[PBGitBinary searchLocations] componentsJoinedByString:@"\n\t"];
	return [NSString stringWithFormat:
			NSLocalizedString(
				@"Could not find a git binary version " MIN_GIT_VERSION " or higher.\n"
				@"Please make sure there is a git binary in one of the following locations:"
				@"\n\n\t%s",
				@"Error message when no git client can be found."),
			searchPathsString];
}


+ (NSString *)version
{
	return [self versionForPath:gitPath];
}

@end
