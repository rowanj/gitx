//
//  PBCloneRepositoryPanel.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBCloneRepositoryPanel.h"
#import "PBRemoteProgressSheet.h"
#import "PBGitDefaults.h"



@implementation PBCloneRepositoryPanel


@synthesize repositoryURL;
@synthesize destinationPath;
@synthesize errorMessage;
@synthesize repositoryAccessoryView;

@synthesize isBare;



#pragma mark -
#pragma mark PBCloneRepositoryPanel

+ (id) panel
{
	return [[self alloc] initWithWindowNibName:@"PBCloneRepositoryPanel"];
}

+ (void)beginCloneRepository:(NSString *)repository toURL:(NSURL *)targetURL isBare:(BOOL)bare
{
	if (!repository || [repository isEqualToString:@""] || !targetURL || [[targetURL path] isEqualToString:@""])
		return;

	PBCloneRepositoryPanel *clonePanel = [PBCloneRepositoryPanel panel];
	[clonePanel showWindow:self];

	[clonePanel.repositoryURL setStringValue:repository];
	[clonePanel.destinationPath setStringValue:[targetURL path]];
	clonePanel.isBare = bare;

	[clonePanel clone:self];
}


- (void) awakeFromNib
{
	[self window];
	[self.errorMessage setStringValue:@""];
	path = [PBGitDefaults recentCloneDestination];
	if (path)
		[self.destinationPath setStringValue:path];
	
	browseRepositoryPanel = [NSOpenPanel openPanel];
	[browseRepositoryPanel setTitle:@"Browse for git repository"];
	[browseRepositoryPanel setMessage:@"Select a folder with a git repository"];
	[browseRepositoryPanel setPrompt:@"Select"];
    [browseRepositoryPanel setCanChooseFiles:NO];
    [browseRepositoryPanel setCanChooseDirectories:YES];
    [browseRepositoryPanel setAllowsMultipleSelection:NO];
	[browseRepositoryPanel setCanCreateDirectories:NO];
	[browseRepositoryPanel setAccessoryView:repositoryAccessoryView];
	
	browseDestinationPanel = [NSOpenPanel openPanel];
	[browseDestinationPanel setTitle:@"Browse clone destination"];
	[browseDestinationPanel setMessage:@"Select a folder to clone the git repository into"];
	[browseDestinationPanel setPrompt:@"Select"];
    [browseDestinationPanel setCanChooseFiles:NO];
    [browseDestinationPanel setCanChooseDirectories:YES];
    [browseDestinationPanel setAllowsMultipleSelection:NO];
	[browseDestinationPanel setCanCreateDirectories:YES];
}


- (void)showErrorSheet:(NSError *)error
{
	[[NSAlert alertWithError:error] beginSheetModalForWindow:[self window]
											   modalDelegate:self
											  didEndSelector:@selector(errorSheetDidEnd:returnCode:contextInfo:)
												 contextInfo:NULL];
}



#pragma mark IBActions

- (IBAction) closeCloneRepositoryPanel:(id)sender
{
	[self close];
}


- (IBAction) clone:(id)sender
{
	[self.errorMessage setStringValue:@""];
	
	NSString *url = [self.repositoryURL stringValue];
	if ([url isEqualToString:@""]) {
		[self.errorMessage setStringValue:@"Repository URL is required"];
		return;
	}
	
	path = [self.destinationPath stringValue];
	if ([path isEqualToString:@""]) {
		[self.errorMessage setStringValue:@"Destination path is required"];
		return;
	}

	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"clone", @"--", url, path, nil];
	if (isBare)
		[arguments insertObject:@"--bare" atIndex:1];
	
	NSString *description = [NSString stringWithFormat:@"Cloning repository at: %@", url];
	NSString *title = @"Cloning Repository";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments
														  title:title
													description:description
														  inDir:nil
											   windowController:nil/*self?*/];
}


- (IBAction) browseRepository:(id)sender
{
    [browseRepositoryPanel beginSheetModalForWindow:[self window]
                                  completionHandler:^(NSInteger result) {
                                      if (result == NSOKButton) {
                                          NSURL *url = [[browseRepositoryPanel URLs] lastObject];
                                          [self.repositoryURL setStringValue:[url path]];
                                      }
                                  }];
}


- (IBAction) showHideHiddenFiles:(id)sender
{
	// This uses undocumented OpenPanel features to show hidden files (required for 10.5 support)
	NSNumber *showHidden = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[browseRepositoryPanel valueForKey:@"_navView"] setValue:showHidden forKey:@"showsHiddenFiles"];
}


- (IBAction) browseDestination:(id)sender
{
    [browseDestinationPanel beginSheetModalForWindow:[self window]
                                   completionHandler:^(NSInteger result) {
                                       if (result == NSOKButton) {
                                           NSURL *url = [[browseDestinationPanel URLs] lastObject];
                                           [self.destinationPath setStringValue:[url path]];
                                       }
                                   }];
}



#pragma mark Callbacks

- (void) messageSheetDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)code contextInfo:(void *)info
{
	NSURL *documentURL = [NSURL fileURLWithPath:path];
	
	NSError *error = nil;
	id document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:documentURL display:YES error:&error];
	if (!document && error)
			[self showErrorSheet:error];
	else {
		[self close];
		
		NSString *containingPath = [path stringByDeletingLastPathComponent];
		[PBGitDefaults setRecentCloneDestination:containingPath];
		[self.destinationPath setStringValue:containingPath];
		[self.repositoryURL setStringValue:@""];
	}
}


- (void) errorSheetDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)code contextInfo:(void *)info
{
	[self close];
}


@end
