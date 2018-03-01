/*
 *  gitx_askpasswd_main.m
 *  GitX
 *
 *  Created by Uli Kusterer on 19.02.10.
 *  Copyright 2010 The Void Software. All rights reserved.
 *
 */

#include <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

#define OKBUTTONWIDTH			100.0
#define OKBUTTONHEIGHT			24.0
#define CANCELBUTTONWIDTH		100.0
#define CANCELBUTTONHEIGHT		24.0
#define	PASSHEIGHT				22.0
#define	PASSLABELHEIGHT			16.0
#define WINDOWAUTOSAVENAME		@"GitXAskPasswordWindowFrame"


@interface GAPAppDelegate : NSObject<NSApplicationDelegate>
{
	NSPanel*			mPasswordPanel;
	NSSecureTextField*	mPasswordField;
}

-(NSPanel*)		passwordPanel;

-(IBAction)	doOKButton: (id)sender;
-(IBAction)	doCancelButton: (id)sender;

@end


@implementation GAPAppDelegate

static const NSInteger kReturnCodeOK = 0;
static const NSInteger kReturnCodeCancel = 1;


-(NSPanel*)	passwordPanel
{
	if( !mPasswordPanel )
	{
		NSRect box = NSMakeRect( 100, 100, 400, 134 );
		mPasswordPanel = [[NSPanel alloc] initWithContentRect: box
													styleMask: NSTitledWindowMask
													  backing: NSBackingStoreBuffered defer: NO];
		[mPasswordPanel setHidesOnDeactivate: NO];
		[mPasswordPanel setLevel: NSFloatingWindowLevel];
		[mPasswordPanel setTitle: NSLocalizedString(@"GitX SSH Remote Login", @"Title for password panel in command line tool")];
        if (![mPasswordPanel setFrameUsingName: WINDOWAUTOSAVENAME]) {
            [mPasswordPanel center];
            [mPasswordPanel setFrameAutosaveName: WINDOWAUTOSAVENAME];
        }
		
		box.origin = NSZeroPoint;	// Only need local coords from now on.
		
		// OK:
		NSRect okBox = box;
		okBox.origin.x = NSMaxX( box ) -OKBUTTONWIDTH -20;
		okBox.size.width = OKBUTTONWIDTH;
		okBox.origin.y += 20;
		okBox.size.height = OKBUTTONHEIGHT;
		NSButton *okButton = [[NSButton alloc] initWithFrame: okBox];
		[okButton setTarget: self];
		[okButton setAction: @selector(doOKButton:)];
		[okButton setTitle: NSLocalizedString(@"OK", @"OK button for password panel in command line tool")];
		[okButton setKeyEquivalent: @"\r"];
		[okButton setBordered: YES];
		[okButton setBezelStyle: NSRoundedBezelStyle];
		[[mPasswordPanel contentView] addSubview: okButton];

		// Cancel:
		NSRect	cancelBox = box;
		cancelBox.origin.x = NSMinX( okBox ) -CANCELBUTTONWIDTH -6;
		cancelBox.size.width = CANCELBUTTONWIDTH;
		cancelBox.origin.y += 20;
		cancelBox.size.height = CANCELBUTTONHEIGHT;
		NSButton *cancleButton = [[NSButton alloc] initWithFrame: cancelBox];
		[cancleButton setTarget: self];
		[cancleButton setAction: @selector(doCancelButton:)];
		[cancleButton setTitle: NSLocalizedString(@"Cancel", @"Cancel button for password panel in command line tool")];
		[cancleButton setBordered: YES];
		[cancleButton setBezelStyle: NSRoundedBezelStyle];
		[[mPasswordPanel contentView] addSubview: cancleButton];
		
		// Password field:
		NSRect passBox = box;
		passBox.origin.y = NSMaxY(okBox) + 24;
		passBox.size.height = PASSHEIGHT;
		passBox.origin.x += 104;
		passBox.size.width -= 104 + 20;
		mPasswordField = [[NSSecureTextField alloc] initWithFrame: passBox];
		[mPasswordField setSelectable: YES];
		[mPasswordField setEditable: YES];
		[mPasswordField setBordered: YES];
		[mPasswordField setBezeled: YES];
		[mPasswordField setBezelStyle: NSTextFieldSquareBezel];
		[mPasswordField selectText: self];
		[[mPasswordPanel contentView] addSubview: mPasswordField];
		
		// Password label:
		NSRect passLabelBox = box;
		passLabelBox.origin.y = NSMaxY(passBox) + 8;
		passLabelBox.size.height = PASSLABELHEIGHT;
		passLabelBox.origin.x += 100;
		passLabelBox.size.width -= 100 + 20;
		NSTextField *passwordLabel = [[NSTextField alloc] initWithFrame: passLabelBox];
		[passwordLabel setSelectable: YES];
		[passwordLabel setEditable: NO];
		[passwordLabel setBordered: NO];
		[passwordLabel setBezeled: NO];
		[passwordLabel setDrawsBackground: NO];
		[passwordLabel setStringValue: NSLocalizedString(@"Please enter your password:", @"Label for password field in password panel in command line tool")];
		[[mPasswordPanel contentView] addSubview: passwordLabel];
		
		// GitX icon:
		NSRect gitxIconBox = box;
		gitxIconBox.origin.y = NSMaxY(box) - 78;
		gitxIconBox.size.height = 64;
		gitxIconBox.origin.x += 20;
		gitxIconBox.size.width = 64;
		NSImageView *gitxIconView = [[NSImageView alloc] initWithFrame: gitxIconBox];
		[gitxIconView setEditable: NO];
		NSString *gitxIconPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"gitx.icns"];
		NSImage *gitxIcon = [[NSImage alloc] initWithContentsOfFile: gitxIconPath];
		[gitxIconView setImage: gitxIcon];
		[[mPasswordPanel contentView] addSubview: gitxIconView];
	}
	
	return mPasswordPanel;
}


-(IBAction)	doOKButton: (id)sender
{
	printf( "%s\n", [[mPasswordField stringValue] UTF8String] );
	[[NSApplication sharedApplication] stopModalWithCode:kReturnCodeOK];
}


// TODO: Need to find out how to get SSH to cancel.
//       When the user cancels the window it is opened again for however
//       many times the remote server allows failed attempts.
-(IBAction)	doCancelButton: (id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:kReturnCodeCancel];
}

@end



int	main( int argc, const char** argv )
{
	@autoreleasepool {
		// close stderr to stop cocoa log messages from being picked up by GitX
		close(STDERR_FILENO);
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		ProcessSerialNumber	myPSN = { 0, kCurrentProcess };
		TransformProcessType( &myPSN, kProcessTransformToForegroundApplication );
		
		NSApplication *app = [NSApplication sharedApplication];
		GAPAppDelegate *appDel = [[GAPAppDelegate alloc] init];
		[app setDelegate: appDel];
		NSWindow *passPanel = [appDel passwordPanel];
		
		[app activateIgnoringOtherApps: YES];
		[passPanel makeKeyAndOrderFront: nil];
		NSInteger code = [app runModalForWindow: passPanel];
		
		[defaults synchronize];

		return code == kReturnCodeOK ? EXIT_SUCCESS : EXIT_FAILURE;
	}
}

