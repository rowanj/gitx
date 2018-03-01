//
//  GitTest_AppDelegate.h
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright __MyCompanyName__ 2008 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"

@interface ApplicationController : NSObject<NSApplicationDelegate>
{
	IBOutlet NSWindow *window;
	IBOutlet id firstResponder;

	BOOL started;
}

- (IBAction)openPreferencesWindow:(id)sender;
- (IBAction)showAboutPanel:(id)sender;

- (IBAction)installCliTool:(id)sender;

- (IBAction)showHelp:(id)sender;
- (IBAction)showChangeLog:(id)sender;
- (IBAction)reportAProblem:(id)sender;
@end
