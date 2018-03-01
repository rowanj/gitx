//
//  PBRepositoryDocumentController.mm
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBRepositoryDocumentController.h"
#import "PBGitRepositoryDocument.h"
#import "PBGitRevList.h"
#import "PBGitBinary.h"
#import "PBClonePanel.h"
#import "PBGitRepository.h"

#import <ObjectiveGit/GTRepository.h>

@implementation PBRepositoryDocumentController

- (void)cloneDocument:(id)sender {
	PBClonePanel *panel = [PBClonePanel clonePanel];

	if ([panel runModal] != NSFileHandlingPanelOKButton) {
		return;
	}

	NSURL *localURL = panel.localURL;
	NSURL *cloneURL = panel.cloneURL;

	NSError *error = nil;

	BOOL success = [GTRepository cloneFromURL:cloneURL toWorkingDirectory:localURL options:nil error:&error transferProgressBlock:^(const git_transfer_progress * _Nonnull progress, BOOL * _Nonnull stop) {

	} checkoutProgressBlock:^(NSString * _Nullable path, NSUInteger completedSteps, NSUInteger totalSteps) {

	}];

	if (!success) {
		[self presentError:error];
		return;
	}

	PBGitRepository *repo = [[PBGitRepository alloc] initWithContentsOfURL:localURL ofType:PBGitRepositoryDocumentType error:&error];
	if (!repo) {
		[self presentError:error];
		return;
	}

	[self addDocument:repo];
	[repo makeWindowControllers];
	[repo showWindows];
}

// This method is overridden to configure the open panel to only allow
// selection of directories
- (void)beginOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray<NSString *> *)inTypes completionHandler:(void (^)(NSInteger))completionHandler {
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"git"]];

	NSModalResponse response = [openPanel runModal];

	completionHandler(response);
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	NSOpenPanel *op = [NSOpenPanel openPanel];

	[op setCanChooseFiles:NO];
	[op setCanChooseDirectories:YES];
	[op setAllowsMultipleSelection:NO];
	[op setTitle:NSLocalizedString(@"New Repository", @"Title of the repository initialisation file selection dialogue box")];
	[op setMessage:NSLocalizedString(@"Initialize a repository here:", @"Message at the top of the repository initialisation file selection dialogue box")];
	[op setNameFieldLabel:@"Repository name:"];
	[op setPrompt:@"Create"];
	// TODO: Bare setting ?
	if ([op runModal] != NSFileHandlingPanelOKButton) {
		if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
		return nil;
	}

	BOOL success = [GTRepository initializeEmptyRepositoryAtFileURL:[op URL] options:nil error:outError];
	if (!success)
		return nil; // Repo creation failed

	return [[PBGitRepositoryDocument alloc] initWithContentsOfURL:[op URL] ofType:PBGitRepositoryDocumentType error:outError];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if ([item action] == @selector(newDocument:))
		return ([PBGitBinary path] != nil);
	return YES;
}

@end
