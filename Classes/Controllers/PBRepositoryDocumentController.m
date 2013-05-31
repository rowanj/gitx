//
//  PBRepositoryDocumentController.mm
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBRepositoryDocumentController.h"
#import "PBGitRepository.h"
#import "PBGitRevList.h"
#import "PBEasyPipe.h"
#import "PBGitBinary.h"
#import "GitRepoFinder.h"

@implementation PBRepositoryDocumentController
// This method is overridden to configure the open panel to only allow
// selection of directories
- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"git"]];
	return [openPanel runModal];
}

// Convert paths to the .git dir before searching for an already open document
- (id)documentForURL:(NSURL *)URL
{
	NSURL* fileURL = [GitRepoFinder fileURLForURL:URL];
	id result = [super documentForURL:fileURL];
	return result;
}

- (void)noteNewRecentDocumentURL:(NSURL*)URL
{
	NSURL* fileURL = [GitRepoFinder fileURLForURL:URL];
	[super noteNewRecentDocumentURL:fileURL];
}

- (id) documentForLocation:(NSURL*) url
{
	id document = [self documentForURL:url];
	if (!document) {
		
		if (!(document = [[PBGitRepository alloc] initWithURL:url]))
			return nil;

		[self addDocument:document];
	}
	else
		[document showWindows];

	return document;
}

- (void)initNewRepositoryAtURL:(NSURL *)url
{
	int terminationStatus;
	NSString *result = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:[NSArray arrayWithObjects:@"init", @"-q", nil] inDir:[url path] retValue:&terminationStatus];

	if (terminationStatus == 0)
		[self openDocumentWithContentsOfURL:url display:YES error:NULL];
	else
		NSRunAlertPanel(@"Failed to create new Git repository", @"Git returned the following error when trying to create the repository: %@", nil, nil, nil, result);
}

- (IBAction)newDocument:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];

	[op setCanChooseFiles:NO];
	[op setCanChooseDirectories:YES];
	[op setAllowsMultipleSelection:NO];
	[op setMessage:@"Initialize a repository here:"];
	[op setTitle:@"New Repository"];
	if ([op runModal] == NSFileHandlingPanelOKButton)
		[self initNewRepositoryAtURL:[op URL]];
}


- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if ([item action] == @selector(newDocument:))
		return ([PBGitBinary path] != nil);
	return [super validateMenuItem:item];
}

@end
