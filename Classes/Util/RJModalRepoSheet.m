//
//  RJModalRepoSheet.m
//  GitX
//
//  Created by Rowan James on 1/7/12.
//  Copyright (c) 2012 Phere Development Pty. Ltd. All rights reserved.
//

#import "RJModalRepoSheet.h"

#import "PBGitRepository.h"
#import "PBGitWindowController.h"
#import "PBGitRepositoryDocument.h"

@interface RJModalRepoSheet () {
	BOOL _hasWindowController;
}

@property (copy) RJSheetCompletionHandler completionHandler;

@end

@implementation RJModalRepoSheet

@dynamic document;

- (instancetype)initWithWindowNibName:(NSString *)windowNibName
{
	return [super initWithWindowNibName:windowNibName];
}

- (instancetype)initWithWindowNibName:(NSString *)windowNibName windowController:(nonnull PBGitWindowController *)windowController
{
	NSParameterAssert(windowController != nil);

	self = [super initWithWindowNibName:windowNibName owner:self];
	if (!self) return nil;

	_windowController = windowController;
	_hasWindowController = YES;

	return self;
}

- (PBGitRepositoryDocument *)document {
	return self.windowController.document;
}

- (PBGitRepository *)repository
{
	return self.document.repository;
}

- (void)beginSheetWithCompletionHandler:(RJSheetCompletionHandler)handler
{
	// Stash the completion handler so we can setup this sheet again in -show
	self.completionHandler = handler;

	[self presentSheet];
}

- (void)presentSheet
{
	NSAssert(!_hasWindowController || self.windowController != nil, @"-beginSheetWithCompletionHandler: called with nil windowController");

	void (^modalHandler)(NSModalResponse returnCode) = ^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseStop) {
			// Something called -hide on us, because it needed to display another sheet.
			// Don't call our handler, because we're not actually done yet.
			return;
		}

		if (self.completionHandler) {
			self.completionHandler(self, returnCode);
		}
	};

	if (_hasWindowController) {
		[self.windowController.window beginSheet:self.window completionHandler:modalHandler];
	} else {
		NSInteger modalResponseMaybe = [NSApp runModalForWindow:self.window];
		modalHandler(modalResponseMaybe);
	}
}

- (void)endSheetWithReturnCode:(NSModalResponse)returnCode
{
	NSAssert(!_hasWindowController || self.windowController != nil, @"-endSheetWithReturnCode: called with nil windowController");

	if (_hasWindowController) {
		[self.windowController.window endSheet:self.window returnCode:returnCode];
	} else {
		[NSApp endSheet:self.window returnCode:returnCode];
	}
}

- (IBAction)acceptSheet:(id)sender
{
	[self endSheetWithReturnCode:NSModalResponseOK];
}

- (IBAction)cancelSheet:(id)sender
{
	[self endSheetWithReturnCode:NSModalResponseCancel];
}

- (void)show
{
	[self presentSheet];
}

- (void)hide
{
	[self endSheetWithReturnCode:NSModalResponseStop];
}

- (void)dismiss
{
	[self endSheetWithReturnCode:NSModalResponseAbort];
}

// For Cmd-. support
- (IBAction)cancelOperation:(id)sender
{
	[self cancelSheet:self];
}

@end
