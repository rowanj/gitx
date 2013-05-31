//
//  PBPrefsWindowController.h
//  GitX
//
//  Created by Christian Jacobsen on 02/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DBPrefsWindowController.h"

@interface PBPrefsWindowController : DBPrefsWindowController {
	/* Outlets for Preference Views */
	IBOutlet NSView *generalPrefsView;
	IBOutlet NSView *integrationPrefsView;
	IBOutlet NSView *updatesPrefsView;

	/* Variables for the Updates View */
	IBOutlet NSPathControl *gitPathController;
	IBOutlet NSImageView *badGitPathIcon;
	IBOutlet NSView *gitPathOpenAccessory;
	NSOpenPanel *gitPathOpenPanel;

}

- (IBAction) checkGitValidity: sender;
- (void)pathCell:(NSPathCell *)pathCell willDisplayOpenPanel:(NSOpenPanel *)openPanel;
- (IBAction) showHideAllFiles: sender;
- (IBAction) resetGitPath: sender;
- (IBAction)resetAllDialogWarnings:(id)sender;

@end
