//
//  gitx.m
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBRepositoryFinder.h"
#import "GitXScriptingConstants.h"
#import "GitX.h"
#import "PBHistorySearchController.h"


#pragma mark Commands handled locally

void usage(char const *programName)
{

	printf("Usage: %s (--help|--version|--git-path)\n", programName);
	printf("   or: %s (--commit)\n", programName);
	printf("   or: %s (--all|--local|--branch) [branch/tag]\n", programName);
	printf("   or: %s <revlist options>\n", programName);
	printf("   or: %s (--diff)\n", programName);
	printf("   or: %s (--init)\n", programName);
	printf("   or: %s (--clone <repository> [destination])\n", programName);
	printf("\n");
	printf("    -h, --help             print this help\n");
	printf("    -v, --version          prints version info for both GitX and git\n");
	printf("    --git-path             prints the path to the directory containing git\n");
	printf("\n");
	printf("Repository path\n");
	printf("    By default gitx opens the repository in the current directory.\n");
	printf("    Use --git-dir= to send commands to a repository somewhere else.\n");
	printf("    Note: This must be the first argument.\n");
	printf("\n");
	printf("    --git-dir=<path> [gitx commands]\n");
	printf("                           send the gitx commands to the repository located at <path>\n");
	printf("\n");
	printf("Commit/Stage view\n");
	printf("    -c, --commit           start GitX in commit/stage mode\n");
	printf("\n");
	printf("Branch filter options\n");
	printf("    Add an optional branch or tag name to select that branch using the given branch filter\n");
	printf("\n");
	printf("    --all [branch]         view history for all branches\n");
	printf("    --local [branch]       view history for local branches only\n");
	printf("    --branch [branch]      view history for the selected branch only\n");
	printf("\n");
	printf("RevList options\n");
	printf("    See 'man git-log' and 'man git-rev-list' for options you can pass to gitx\n");
	printf("\n");
	printf("    <branch>               select specific branch or tag\n");
	printf("     -- <path(s)>          show commits touching paths\n");
	printf("\n");
	printf("Diff options\n");
	printf("    See 'man git-diff' for options you can pass to gitx --diff\n");
	printf("\n");
	printf("    -d, --diff [<common diff options>] <commit>{0,2} [--] [<path>...]\n");
	printf("                            shows the diff in a window in GitX\n");
	printf("    git diff [options] | gitx\n");
	printf("                            use gitx to pipe diff output to a GitX window\n");
	printf("\n");
	printf("Search\n");
	printf("\n");
	printf("    -s<string>, --search=<string>\n");
	printf("                           search for string in Subject, Author or SHA\n");
	printf("    -S<string>, --Search=<string>\n");
	printf("                           commits that introduce or remove an instance of <string>\n");
	printf("    -r<regex>, --regex=<regex>\n");
	printf("                           commits that introduce or remove strings that match <regex>\n");
	printf("    -p<file path>, --path=<file path>\n");
	printf("                           commits that modify the file at file path\n");
	printf("\n");
	printf("Creating repositories\n");
	printf("    These commands will create a git repository and then open it up in GitX\n");
	printf("\n");
	printf("    --init                  creates (or reinitializes) a git repository\n");
	printf("    --clone <repository URL> [destination path]\n");
	printf("                            clones the repository (at the specified URL) into the current\n");
	printf("                            directory or into the specified path\n");
	printf("\n");
	exit(1);
}

void version_info()
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
	printf("GitX version %s\n", [version UTF8String]);
	exit(1);
}

#pragma mark -
#pragma mark Commands sent to GitX

void handleSTDINDiff()
{
	NSFileHandle *handle = [NSFileHandle fileHandleWithStandardInput];
	NSData *data = [handle readDataToEndOfFile];
	NSString *diff = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if (diff && [diff length] > 0) {
		GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
		[gitXApp showDiff:diff];
		exit(0);
	}
}

void handleDiffWithArguments(NSURL *repositoryURL, NSArray *arguments)
{
	GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
	[gitXApp performDiffIn:repositoryURL withOptions:arguments];

	exit(0);
}

void handleOpenRepository(NSURL *repositoryURL, NSArray *arguments)
{
    GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
    [gitXApp open:repositoryURL withOptions:arguments];
    return;
}

void handleInit(NSURL *repositoryURL)
{
	GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
	[gitXApp createRepository:repositoryURL];

	exit(0);
}

void handleClone(NSURL *repositoryURL, NSMutableArray *arguments)
{
	if ([arguments count]) {
		NSString *repository = [arguments objectAtIndex:0];

		if ([arguments count] > 1) {
			NSURL *url = [NSURL fileURLWithPath:[arguments objectAtIndex:1]];
			if (url)
				repositoryURL = url;
		}

		GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
		[gitXApp cloneRepository:repository to:repositoryURL isBare:NO];
	}
	else {
		printf("Error: --clone needs the URL of the repository to clone.\n");
		exit(2);
	}


	exit(0);
}

#define kShortBasicSearch @"-s"
#define kBasicSearch @"--search="
#define kShortPickaxeSearch @"-S"
#define kPickaxeSearch @"--Search="
#define kShortRegexSearch @"-r"
#define kRegexSearch @"--regex="
#define kShortPathSearch @"-p"
#define kPathSearch @"--path="

NSArray *commandLineSearchPrefixes()
{
	return [NSArray arrayWithObjects:kShortBasicSearch, kBasicSearch, kShortPickaxeSearch, kPickaxeSearch, kShortRegexSearch, kRegexSearch, kShortPathSearch, kPathSearch, nil];
}

PBHistorySearchMode searchModeForCommandLineArgument(NSString *argument)
{
	if ([argument hasPrefix:kShortBasicSearch] || [argument hasPrefix:kBasicSearch])
		return kGitXBasicSeachMode;

	if ([argument hasPrefix:kShortPickaxeSearch] || [argument hasPrefix:kPickaxeSearch])
		return kGitXPickaxeSearchMode;

	if ([argument hasPrefix:kShortRegexSearch] || [argument hasPrefix:kRegexSearch])
		return kGitXRegexSearchMode;

	if ([argument hasPrefix:kShortPathSearch] || [argument hasPrefix:kPathSearch])
		return kGitXPathSearchMode;

	return 0;
}

GitXDocument *documentForURL(SBElementArray *documents, NSURL *theURL)
{
	for (GitXDocument *document in documents)
	{
		NSURL* docURL = [document file];
		if ([docURL isEqualTo:theURL])
		{
			return document;
		}
	}
	return nil;
}

void handleGitXSearch(NSURL *repositoryURL, NSMutableArray *arguments)
{
	NSString *searchString = [arguments componentsJoinedByString:@" "];
	NSInteger mode = searchModeForCommandLineArgument(searchString);

	// remove the prefix from search string before sending it
	NSArray *prefixes = commandLineSearchPrefixes();
	for (NSString *prefix in prefixes)
		if ([searchString hasPrefix:prefix]) {
			searchString = [searchString substringFromIndex:[prefix length]];
			break;
		}

	if ([searchString isEqualToString:@""])
		exit(0);

	GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
	[gitXApp open:[NSArray arrayWithObject:repositoryURL]];

	// need to find the document after opening it
	GitXDocument *repositoryDocument = documentForURL([gitXApp documents], repositoryURL);
	[repositoryDocument searchString:searchString inMode:mode];

	exit(0);
}


#pragma mark -
#pragma mark main

#define kGitDirPrefix @"--git-dir"

NSURL *checkWorkingDirectoryPath(NSString *path)
{
	NSString *workingDirectory = [[[NSProcessInfo processInfo] environment] objectForKey:@"PWD"];

	// We might be looking at a filesystem path, try to standardize it
	if (!([path hasPrefix:@"/"] || [path hasPrefix:@"~"])) {
		path = [workingDirectory stringByAppendingPathComponent:path];
	}
	path = [path stringByStandardizingPath];

	// The path must exist and point to a directory
	BOOL isDirectory = YES;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
	if (!exists || !isDirectory) {
		return nil;
	}

	return [NSURL fileURLWithPath:path];
}

NSURL *workingDirectoryURL(NSMutableArray *arguments)
{
	NSString *workingDirectory = [[[NSProcessInfo processInfo] environment] objectForKey:@"PWD"];

	// First check our arguments for a --git-dir option
	for (NSUInteger i = 0; i < [arguments count]; i++) {
		NSString *argument = [arguments objectAtIndex:i];
		NSString *path = nil;

		if (![argument hasPrefix:kGitDirPrefix]) {
			// That's not a --git-dir argument, don't bother
			continue;
		}

		BOOL isInlinePath = NO;
		if ([argument hasPrefix:kGitDirPrefix @"="]) {
			// We're looking at a --git-dir=, extract the argument
			path = [argument substringFromIndex:[kGitDirPrefix length] + 1];
			isInlinePath = YES;
		} else {
			// We're looking at a --git-dir [arg], next argument is our path
			path = [arguments objectAtIndex:i + 1];
		}

		NSURL *url = checkWorkingDirectoryPath(path);

		// Let's check that this points to a repository
		url = [PBRepositoryFinder workDirForURL:url];
		if (!url) {
			NSLog(@"Fatal: --git-dir \"%@\" does not look like a valid repository.", argument);
			exit(2);
		}

		// Valid --git-dir found, let's drop parsed arguments
		[arguments removeObjectAtIndex:i];
		if (!isInlinePath) {
			[arguments removeObjectAtIndex:i];
		}

		return url;
	}

	// No --git-dir option, let's use the first thing that looks like a path
	for (NSUInteger i = 0; i < [arguments count]; i++) {
		NSString *path = [arguments objectAtIndex:i];

		// Stop processing arguments willy-nilly, we'll just give the CWD a spin.
		// The user might be trying todo a `gitx log -- path` or something.
		if ([path isEqualToString:@"--"]) break;

		// Let's check that path and find the closest repository
		NSURL *url = checkWorkingDirectoryPath(path);
		url = [PBRepositoryFinder fileURLForURL:url];
		if (!url) continue; // Invalid path, let's ignore it

		// Valid repository found, lets' drop parsed argument
		[arguments removeObjectAtIndex:i];

		return url;
	}

	// Still no path found, let's default to our current working directory
	return [PBRepositoryFinder fileURLForURL:[NSURL fileURLWithPath:workingDirectory]];
}

int main(int argc, const char** argv)
{
	@autoreleasepool {
		if (argc >= 2 && (!strcmp(argv[1], "--help") || !strcmp(argv[1], "-h")))
			usage(argv[0]);
		if (argc >= 2 && (!strcmp(argv[1], "--version") || !strcmp(argv[1], "-v")))
			version_info();
		if (argc >= 2 && !strcmp(argv[1], "--git-path")) {
            printf("gitx now uses libgit2 to work.");
            exit(1);
        }

		// gitx can be used to pipe diff output to be displayed in GitX
		if (!isatty(STDIN_FILENO) && fdopen(STDIN_FILENO, "r"))
			handleSTDINDiff();


		NSMutableArray *arguments = [[[NSProcessInfo processInfo] arguments] mutableCopy];
		[arguments removeObjectAtIndex:0]; // url to executable path is not needed

		// From this point, we require a working directory and the arguments
		NSURL *wdURL = workingDirectoryURL(arguments);
		if (!wdURL)
		{
			printf("Could not find a git working directory.\n");
			exit(0);
		}
		
		if ([arguments count]) {
			NSString *firstArgument = [arguments objectAtIndex:0];
			
			if ([firstArgument isEqualToString:@"--diff"] || [firstArgument isEqualToString:@"-d"]) {
				[arguments removeObjectAtIndex:0];
				handleDiffWithArguments(wdURL, arguments);
			}
			
			if ([firstArgument isEqualToString:@"--init"]) {
				[arguments removeObjectAtIndex:0];
				handleInit(wdURL);
			}
			
			if ([firstArgument isEqualToString:@"--clone"]) {
				[arguments removeObjectAtIndex:0];
				handleClone(wdURL, arguments);
			}
			
			if (searchModeForCommandLineArgument(firstArgument)) {
				handleGitXSearch(wdURL, arguments);
			}
		}
		
		// No commands handled by gitx, open the current dir in GitX with the arguments
		handleOpenRepository(wdURL, arguments);
		
		return 0;
	}
}
