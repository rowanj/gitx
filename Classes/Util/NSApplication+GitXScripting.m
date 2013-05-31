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
#import "PBRepositoryDocumentController.h"
#import "PBCloneRepositoryPanel.h"


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

- (void)initRepositoryScriptCommand:(NSScriptCommand *)command
{
	NSURL *repositoryURL = [command directParameter];
	if (repositoryURL)
		[[PBRepositoryDocumentController sharedDocumentController] initNewRepositoryAtURL:repositoryURL];
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
