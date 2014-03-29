//
//  NSApplication+GitXScripting.m
//  GitX
//
//  Created by Nathan Kinsinger on 8/15/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "NSApplication+GitXScripting.h"
#import "GitXScriptingConstants.h"
#import "PBDiffWindowController.h"
#import "PBGitRepository.h"
#import "PBCloneRepositoryPanel.h"
#import "PBGitBinary.h"
#import "PBEasyPipe.h"


@implementation NSApplication (GitXScripting)

- (void)showDiffScriptCommand:(NSScriptCommand *)command
{
	NSString *diffText = [command directParameter];
	if (diffText) {
		PBDiffWindowController *diffController = [[PBDiffWindowController alloc] initWithDiff:diffText];
		[diffController showWindow:nil];
		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	}
}

- (void)performDiffScriptCommand:(NSScriptCommand *)command
{
    NSURL *repositoryURL = command.directParameter;
    NSArray *diffOptions = command.arguments[@"diffOptions"];

	diffOptions = [[NSArray arrayWithObjects:@"diff", @"--no-ext-diff", nil] arrayByAddingObjectsFromArray:diffOptions];

	int retValue = 1;
	NSString *diffOutput = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:diffOptions inDir:[repositoryURL path] retValue:&retValue];
	if (retValue) {
		// if there is an error diffOutput should have the error output from git
		if (diffOutput)
			NSLog(@"%s\n", [diffOutput UTF8String]);
		else
			NSLog(@"Invalid diff command [%d]\n", retValue);
        return;
	}

    if (diffOutput) {
        PBDiffWindowController *diffController = [[PBDiffWindowController alloc] initWithDiff:diffOutput];
        [diffController showWindow:self];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}

- (void)initRepositoryScriptCommand:(NSScriptCommand *)command
{
    NSError *error = nil;
	NSURL *repositoryURL = [command directParameter];
	if (!repositoryURL)
        return;

    BOOL success = [GTRepository initializeEmptyRepositoryAtFileURL:repositoryURL error:&error];
    if (!success) {
        NSLog(@"Failed to create repository at %@: %@", repositoryURL, error);
        return;
    }

    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:repositoryURL
                                                                           display:YES
                                                                 completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
                                                                     if (error) {
                                                                         NSLog(@"Failed to open repository at %@: %@", repositoryURL, error);
                                                                     }
                                                                 }];
}

- (void)cloneRepositoryScriptCommand:(NSScriptCommand *)command
{
	NSString *repository = [command directParameter];
	if (repository) {
		NSDictionary *arguments = [command arguments];
		NSURL *destinationURL = [arguments objectForKey:kGitXCloneDestinationURLKey];
		if (destinationURL) {
			BOOL isBare = [[arguments objectForKey:kGitXCloneIsBareKey] boolValue];

			[PBCloneRepositoryPanel beginCloneRepository:repository toURL:destinationURL isBare:isBare];
		}
	}
}

@end
