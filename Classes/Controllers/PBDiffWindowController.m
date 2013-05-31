//
//  PBDiffWindowController.m
//  GitX
//
//  Created by Pieter de Bie on 13-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBDiffWindowController.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitDefaults.h"


@implementation PBDiffWindowController
@synthesize diff;

- (id) initWithDiff:(NSString *)aDiff
{
    self = [super initWithWindowNibName:@"PBDiffWindow"];

    if (self)
        diff = aDiff;
    
	return self;
}


+ (void) showDiffWindowWithFiles:(NSArray *)filePaths fromCommit:(PBGitCommit *)startCommit diffCommit:(PBGitCommit *)diffCommit
{
	if (!startCommit)
		return;

	if (!diffCommit)
		diffCommit = [startCommit.repository headCommit];

	NSString *commitSelector = [NSString stringWithFormat:@"%@..%@", [startCommit realSha], [diffCommit realSha]];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"diff", @"--no-ext-diff", commitSelector, nil];

	if (![PBGitDefaults showWhitespaceDifferences])
		[arguments insertObject:@"-w" atIndex:1];

	if (filePaths) {
		[arguments addObject:@"--"];
		[arguments addObjectsFromArray:filePaths];
	}

	int retValue;
	NSString *diff = [startCommit.repository outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSLog(@"diff failed with retValue: %d   for command: '%@'    output: '%@'", retValue, [arguments componentsJoinedByString:@" "], diff);
		return;
	}

	PBDiffWindowController *diffController = [[PBDiffWindowController alloc] initWithDiff:[diff copy]];
	[diffController showWindow:nil];
}


@end
