//
//  PBPrefsWindowController.m
//  GitX
//
//  Created by Christian Jacobsen on 02/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBPrefsWindowController.h"
#import "PBGitRepository.h"
#import "PBGitDefaults.h"

#define kPreferenceViewIdentifier @"PBGitXPreferenceViewIdentifier"

@implementation PBPrefsWindowController

# pragma mark DBPrefsWindowController overrides

- (void)setupToolbar
{
	// GENERAL
	[self addView:generalPrefsView label:@"General" image:[NSImage imageNamed:@"gitx"]];
	// INTERGRATION
	[self addView:integrationPrefsView label:@"Integration" image:[NSImage imageNamed:NSImageNameNetwork]];
	// UPDATES
	[self addView:updatesPrefsView label:@"Updates"];
}

- (void)displayViewForIdentifier:(NSString *)identifier animate:(BOOL)animate
{
	[super displayViewForIdentifier:identifier animate:animate];

	[[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kPreferenceViewIdentifier];
}

- (NSString *)defaultViewIdentifier
{
	NSString *identifier = [[NSUserDefaults standardUserDefaults] objectForKey:kPreferenceViewIdentifier];
	if (identifier)
		return identifier;

	return [super defaultViewIdentifier];
}

#pragma mark -
#pragma mark Delegate methods

- (IBAction) checkGitValidity: sender
{
	// FIXME: This does not work reliably, probably due to: http://www.cocoabuilder.com/archive/message/cocoa/2008/9/10/217850
	//[badGitPathIcon setHidden:[PBGitRepository validateGit:[[NSValueTransformer valueTransformerForName:@"PBNSURLPathUserDefaultsTransfomer"] reverseTransformedValue:[gitPathController URL]]]];
}

- (IBAction) resetGitPath: sender
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"gitExecutable"];
}

- (void)pathCell:(NSPathCell *)pathCell willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTreatsFilePackagesAsDirectories:YES];
	[openPanel setAccessoryView:gitPathOpenAccessory];
	[openPanel setResolvesAliases:NO];
	//[[openPanel _navView] setShowsHiddenFiles:YES];

	gitPathOpenPanel = openPanel;
}

- (IBAction)resetAllDialogWarnings:(id)sender
{
	[PBGitDefaults resetAllDialogWarnings];
}

#pragma mark -
#pragma mark Git Path open panel actions

- (IBAction) showHideAllFiles: sender
{
	/* FIXME: This uses undocumented OpenPanel features to show hidden files! */
	NSNumber *showHidden = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[gitPathOpenPanel valueForKey:@"_navView"] setValue:showHidden forKey:@"showsHiddenFiles"];
}

@end
