//
//  GitTest_AppDelegate.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright __MyCompanyName__ 2008 . All rights reserved.
//

#import "ApplicationController.h"
#import "PBRepositoryDocumentController.h"
#import "PBGitRevisionCell.h"
#import "PBGitWindowController.h"
#import "PBServicesController.h"
#import "PBGitXProtocol.h"
#import "PBPrefsWindowController.h"
#import "PBNSURLPathUserDefaultsTransfomer.h"
#import "PBGitDefaults.h"
#import "OpenRecentController.h"
#import "PBGitBinary.h"

#import <Sparkle/SUUpdater.h>
#import <Sparkle/SUUpdaterDelegate.h>

static OpenRecentController* recentsDialog = nil;

@interface ApplicationController () <SUUpdaterDelegate>
@end

@implementation ApplicationController

- (ApplicationController*)init
{
#ifdef DEBUG_BUILD
	[NSApp activateIgnoringOtherApps:YES];
#endif

	if(!(self = [super init]))
		return nil;

	if(![[NSBundle bundleWithPath:@"/System/Library/Frameworks/Quartz.framework/Frameworks/QuickLookUI.framework"] load])
		if(![[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/QuickLookUI.framework"] load])
			NSLog(@"Could not load QuickLook");

	/* Value Transformers */
	NSValueTransformer *transformer = [[PBNSURLPathUserDefaultsTransfomer alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:@"PBNSURLPathUserDefaultsTransfomer"];
	
	// Make sure the PBGitDefaults is initialized, by calling a random method
	[PBGitDefaults class];
	
	started = NO;
	return self;
}

- (void)registerServices
{
	// Register URL
	[NSURLProtocol registerClass:[PBGitXProtocol class]];

	// Register the service class
	PBServicesController *services = [[PBServicesController alloc] init];
	[NSApp setServicesProvider:services];

	// Force update the services menu if we have a new services version
	NSInteger serviceVersion = [[NSUserDefaults standardUserDefaults] integerForKey:@"Services Version"];
	if (serviceVersion < 2)
	{
		NSLog(@"Updating services menu…");
		NSUpdateDynamicServices();
		[[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"Services Version"];
	}
}

- (void)application:(NSApplication *)sender openFiles:(NSArray <NSString *> *)filenames {
	PBRepositoryDocumentController * controller = [PBRepositoryDocumentController sharedDocumentController];
	
	for (NSString * filename in filenames) {
		NSURL * repository = [NSURL fileURLWithPath:filename];
		[controller openDocumentWithContentsOfURL:repository display:YES
								completionHandler:^void (NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
									if (!document) {
										NSLog(@"Error opening repository \"%@\": %@", repository.path, error);
										[controller presentError:error];
										[sender replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
									}
									else {
										[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
									}
								}];
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	if(!started || [[[NSDocumentController sharedDocumentController] documents] count])
		return NO;
	return YES;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
	recentsDialog = [[OpenRecentController alloc] init];
	if ([recentsDialog.possibleResults count] > 0)
	{
		[recentsDialog show];
		return YES;
	}
	else
	{
		return NO;
	}
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	[[SUUpdater sharedUpdater] setSendsSystemProfile:YES];
    [[SUUpdater sharedUpdater] setDelegate:self];

	// Make sure Git's SSH password requests get forwarded to our little UI tool:
	setenv( "SSH_ASKPASS", [[[NSBundle mainBundle] pathForResource: @"gitx_askpasswd" ofType: @""] UTF8String], 1 );
	setenv( "DISPLAY", "localhost:0", 1 );

	[self registerServices];
	started = YES;
}

- (void) windowWillClose: sender
{
	[firstResponder terminate: sender];
}

//Override the default behavior
- (IBAction)openDocument:(id)sender {
	NSOpenPanel* panel = [[NSOpenPanel alloc] init];
	
	[panel setCanChooseFiles:false];
	[panel setCanChooseDirectories:true];
	
	[panel beginWithCompletionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			PBRepositoryDocumentController* controller = [PBRepositoryDocumentController sharedDocumentController];
			[controller openDocumentWithContentsOfURL:panel.URL display:true completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
				if (!document) {
					NSLog(@"Error opening repository \"%@\": %@", panel.URL.path, error);
					[controller presentError:error];
				}
			}];
		}
	}];
}

- (IBAction)openPreferencesWindow:(id)sender
{
	[[PBPrefsWindowController sharedPrefsWindowController] showWindow:nil];
}

- (IBAction)showAboutPanel:(id)sender
{
	NSString *gitversion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleGitVersion"];
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	if (gitversion)
		[dict addEntriesFromDictionary:[[NSDictionary alloc] initWithObjectsAndKeys:gitversion, @"Version", nil]];

	#ifdef DEBUG_BUILD
		[dict addEntriesFromDictionary:[[NSDictionary alloc] initWithObjectsAndKeys:@"GitX-dev (DEBUG)", @"ApplicationName", nil]];
	#endif

	[dict addEntriesFromDictionary:[[NSDictionary alloc] initWithObjectsAndKeys:@"GitX-dev (rowanj fork)", @"ApplicationName", nil]];

	[NSApp orderFrontStandardAboutPanelWithOptions:dict];
}

- (IBAction)installCliTool:(id)sender;
{
	BOOL success               = NO;
	NSString* installationPath = @"/usr/local/bin/";
	NSString* installationName = @"gitx";
	NSString* toolPath         = [[NSBundle mainBundle] pathForResource:@"gitx" ofType:@""];
	if (toolPath) {
		AuthorizationRef auth;
		if (AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) == errAuthorizationSuccess) {
			char const* mkdir_arg[] = { "-p", [installationPath UTF8String], NULL};
			char const* mkdir	= "/bin/mkdir";
			AuthorizationExecuteWithPrivileges(auth, mkdir, kAuthorizationFlagDefaults, (char**)mkdir_arg, NULL);
			char const* arguments[] = { "-f", "-s", [toolPath UTF8String], [[installationPath stringByAppendingString: installationName] UTF8String],  NULL };
			char const* helperTool  = "/bin/ln";
			if (AuthorizationExecuteWithPrivileges(auth, helperTool, kAuthorizationFlagDefaults, (char**)arguments, NULL) == errAuthorizationSuccess) {
				int status;
				int pid = wait(&status);
				if (pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
					success = true;
				else
					errno = WEXITSTATUS(status);
			}

			AuthorizationFree(auth, kAuthorizationFlagDefaults);
		}
	}

	NSAlert * alert = [[NSAlert alloc] init];
	if (success) {
		alert.messageText = NSLocalizedString(@"Installation Complete", @"Headline for successfully completed installation of the command line tool");
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"The gitx tool has been installed to %@.", @"Informative text for successfully completed installation of the command line tool at the location %@"), installationPath];
	} else {
		alert.messageText = NSLocalizedString(@"Installation Failed", @"Headline for failed installation of the command line tool");
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Installation to %@ failed.", @"Informative text for successfully completed installation of the command line tool at the location %@"), installationPath];
	}
	[alert runModal];
}

#pragma mark Sparkle delegate methods

- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile
{
	NSArray *keys = [NSArray arrayWithObjects:@"key", @"displayKey", @"value", @"displayValue", nil];
	NSMutableArray *feedParameters = [NSMutableArray array];

    // only add parameters if the profile is being sent this time
    if (sendingProfile) {
        NSString *CFBundleGitVersion = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleGitVersion"];
		if (CFBundleGitVersion)
			[feedParameters addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"CFBundleGitVersion", @"Full Version", CFBundleGitVersion, CFBundleGitVersion, nil] 
																  forKeys:keys]];

        NSString *gitVersion = [PBGitBinary version];
		if (gitVersion)
			[feedParameters addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"gitVersion", @"git Version", gitVersion, gitVersion, nil] 
																  forKeys:keys]];
	}

    return feedParameters;
}


#pragma mark Help menu

- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gitx.github.io"]];
}

- (IBAction)reportAProblem:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/gitx/gitx/issues"]];
}

- (IBAction)showChangeLog:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/gitx/gitx/releases"]];
}



@end
