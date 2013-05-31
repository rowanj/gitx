//
//  PBAddRemoteSheet.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/8/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBAddRemoteSheet.h"
#import "PBGitWindowController.h"
#import "PBGitRepository.h"

@implementation PBAddRemoteSheet

@synthesize remoteName;
@synthesize remoteURL;
@synthesize errorMessage;

@synthesize browseSheet;
@synthesize browseAccessoryView;



#pragma mark -
#pragma mark PBAddRemoteSheet

- (id) initWithRepository:(PBGitRepository *)repo
{
	self = [super initWithWindowNibName:@"PBAddRemoteSheet" forRepo:repo];
	if (!self)
		return nil;

	return self;
}

- (void) show
{
	[self.errorMessage setStringValue:@""];
	[super show];
}


- (void) browseSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(void *)info
{
	[self hide];

    if (code == NSOKButton)
	{
		NSOpenPanel* panel = (NSOpenPanel*)sheet;
		NSString* directory = panel.directoryURL.path;
		[self.remoteURL setStringValue:directory];
	}

	[self show];
}



#pragma mark IBActions

- (IBAction) browseFolders:(id)sender
{
	[self hide];

    self.browseSheet = [NSOpenPanel openPanel];

	[browseSheet setTitle:@"Add remote"];
    [browseSheet setMessage:@"Select a folder with a git repository"];
    [browseSheet setCanChooseFiles:NO];
    [browseSheet setCanChooseDirectories:YES];
    [browseSheet setAllowsMultipleSelection:NO];
    [browseSheet setCanCreateDirectories:NO];
	[browseSheet setAccessoryView:browseAccessoryView];

    [browseSheet beginSheetForDirectory:nil file:nil types:nil
						 modalForWindow:self.repoWindow.window
						  modalDelegate:self
						 didEndSelector:@selector(browseSheetDidEnd:returnCode:contextInfo:)
							contextInfo:NULL];
}


- (IBAction) addRemote:(id)sender
{
	[self.errorMessage setStringValue:@""];

	NSString *name = [[self.remoteName stringValue] copy];

	if ([name isEqualToString:@""]) {
		[self.errorMessage setStringValue:@"Remote name is required"];
		return;
	}

	if (![self.repository checkRefFormat:[@"refs/remotes/" stringByAppendingString:name]]) {
		[self.errorMessage setStringValue:@"Invalid remote name"];
		return;
	}

	NSString *url = [[self.remoteURL stringValue] copy];
	if ([url isEqualToString:@""]) {
		[self.errorMessage setStringValue:@"Remote URL is required"];
		return;
	}

	PBGitRepository* repo = self.repository;
	[self hide]; // may deallocate self
	[repo beginAddRemote:name forURL:url];
}

- (IBAction) showHideHiddenFiles:(id)sender
{
	// This uses undocumented OpenPanel features to show hidden files (required for 10.5 support)
	NSNumber *showHidden = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[self.browseSheet valueForKey:@"_navView"] setValue:showHidden forKey:@"showsHiddenFiles"];
}

- (IBAction) cancelOperation:(id)sender
{
//	[super cancelOperation:sender];
	[self hide];
}

@end
