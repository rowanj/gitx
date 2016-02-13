//
//  gitx.m
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitBinary.h"
#import "PBEasyPipe.h"
#import "GitXScriptingConstants.h"
#import "GitX.h"
#import "PBHistorySearchController.h"
#import "GitRepoFinder.h"


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
	NSString *version = [[[NSBundle bundleForClass:[PBGitBinary class]] infoDictionary] valueForKey:@"CFBundleVersion"];
	NSString *gitVersion = [[[NSBundle bundleForClass:[PBGitBinary class]] infoDictionary] valueForKey:@"CFBundleGitVersion"];
	printf("GitX version %s (%s)\n", [version UTF8String], [gitVersion UTF8String]);
	if ([PBGitBinary path])
		printf("Using git found at %s, version %s\n", [[PBGitBinary path] UTF8String], [[PBGitBinary version] UTF8String]);
	else
		printf("GitX cannot find a git binary\n");
	exit(1);
}

void git_path()
{
	if (![PBGitBinary path])
		exit(101);

	NSString *path = [[PBGitBinary path] stringByDeletingLastPathComponent];
	printf("%s\n", [path UTF8String]);
	exit(0);
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
	arguments = [[NSArray arrayWithObjects:@"diff", @"--no-ext-diff", nil] arrayByAddingObjectsFromArray:arguments];

	int retValue = 1;
	NSString *diffOutput = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:[repositoryURL path] retValue:&retValue];
	if (retValue) {
		// if there is an error diffOutput should have the error output from git
		if (diffOutput)
			printf("%s\n", [diffOutput UTF8String]);
		else
			printf("Invalid diff command [%d]\n", retValue);
		exit(3);
	}

	GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
	[gitXApp showDiff:diffOutput];

	exit(0);
}

void handleOpenRepository(NSURL *repositoryURL, NSMutableArray *arguments)
{
	// if there are command line arguments send them to GitX through an Apple Event
	// the recordDescriptor will be stored in keyAEPropData inside the openDocument or openApplication event
	NSAppleEventDescriptor *recordDescriptor = nil;
	if ([arguments count]) {
		recordDescriptor = [NSAppleEventDescriptor recordDescriptor];

		NSAppleEventDescriptor *listDescriptor = [NSAppleEventDescriptor listDescriptor];
		uint listIndex = 1; // AppleEvent list descriptor's are one based
		for (NSString *argument in arguments)
			[listDescriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithString:argument] atIndex:listIndex++];

		[recordDescriptor setParamDescriptor:listDescriptor forKeyword:kGitXAEKeyArgumentsList];

		// this is used as a double check in GitX
		NSAppleEventDescriptor *url = [NSAppleEventDescriptor descriptorWithString:[repositoryURL absoluteString]];
		[recordDescriptor setParamDescriptor:url forKeyword:typeFileURL];
	}

	// use NSWorkspace to open GitX and send the arguments
	// this allows the repository document to modify itself before it shows it's GUI
	BOOL didOpenURLs = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:repositoryURL]
									   withAppBundleIdentifier:kGitXBundleIdentifier
													   options:0
								additionalEventParamDescriptor:recordDescriptor
											 launchIdentifiers:NULL];
	if (!didOpenURLs) {
		printf("Unable to open GitX.app\n");
		exit(2);
	}
}

void handleInit(NSURL *repositoryURL)
{
	GitXApplication *gitXApp = [SBApplication applicationWithBundleIdentifier:kGitXBundleIdentifier];
	[gitXApp initRepository:repositoryURL];

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


#define kGitDirPrefix @"--git-dir="

NSURL *workingDirectoryURL(NSMutableArray *arguments)
{
    // path to git repository has been explicitly passed?
	if ([arguments count] && [[arguments objectAtIndex:0] hasPrefix:kGitDirPrefix]) {
		NSString *path = [[[arguments objectAtIndex:0] substringFromIndex:[kGitDirPrefix length]] stringByStandardizingPath];

		// the path must exist and point to a directory
		BOOL isDirectory = YES;
		if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
			if (!isDirectory)
				printf("Fatal: --git-dir path does not point to a directory.\n");
			else
				printf("Fatal: --git-dir path does not exist.\n");
			printf("Cannot open git repository at path: '%s'\n", [path UTF8String]);
			exit(2);
		}

		// remove the git-dir argument
		[arguments removeObjectAtIndex:0];

        // create and return corresponding NSURL
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
        if (!url) {
            printf("Unable to create url to path: %s\n", [path UTF8String]);
            exit(2);
        }

        return url;
	}

    // otherwise, determine current working directory
    NSString *pwd = [[[NSProcessInfo processInfo] environment] objectForKey:@"PWD"];

	NSURL* pwdURL = [NSURL fileURLWithPath:pwd];
	NSURL* repoURL = [GitRepoFinder workDirForURL:pwdURL];
	return repoURL;

}

NSMutableArray *argumentsArray()
{
	NSMutableArray *arguments = [[[NSProcessInfo processInfo] arguments] mutableCopy];
	[arguments removeObjectAtIndex:0]; // url to executable path is not needed

	return arguments;
}

int main(int argc, const char** argv)
{
	@autoreleasepool {
		if (argc >= 2 && (!strcmp(argv[1], "--help") || !strcmp(argv[1], "-h")))
			usage(argv[0]);
		if (argc >= 2 && (!strcmp(argv[1], "--version") || !strcmp(argv[1], "-v")))
			version_info();
		if (argc >= 2 && !strcmp(argv[1], "--git-path"))
			git_path();
		
		// From here on everything needs to access git, so make sure it's installed
		if (![PBGitBinary path]) {
			printf("%s\n", [[PBGitBinary notFoundError] cStringUsingEncoding:NSUTF8StringEncoding]);
			exit(2);
		}
		
		// gitx can be used to pipe diff output to be displayed in GitX
		if (!isatty(STDIN_FILENO) && fdopen(STDIN_FILENO, "r"))
			handleSTDINDiff();
		
		// From this point, we require a working directory and the arguments
		NSMutableArray *arguments = argumentsArray();
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
