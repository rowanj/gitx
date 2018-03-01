//
//  PBCommitHookFailedSheet.m
//  GitX
//
//  Created by Sebastian Staudt on 9/12/10.
//  Copyright 2010 Sebastian Staudt. All rights reserved.
//

#import "PBCommitHookFailedSheet.h"
#import "PBGitWindowController.h"


@implementation PBCommitHookFailedSheet

@synthesize commitController;

#pragma mark -
#pragma mark PBCommitHookFailedSheet


+ (void)beginWithMessageText:(NSString *)message
					infoText:(NSString *)info
			commitController:(PBGitCommitController *)controller
		   completionHandler:(RJSheetCompletionHandler)handler;
{
	PBCommitHookFailedSheet* sheet = [[self alloc] initWithWindowNibName:@"PBCommitHookFailedSheet"
														   andController:controller];
	[sheet beginMessageSheetWithMessageText:message
								   infoText:info
						  completionHandler:handler];
}

- (id)initWithWindowNibName:(NSString*)windowNibName
			  andController:(PBGitCommitController*)controller;
{
    self = [self initWithWindowNibName:windowNibName windowController:controller.windowController];
	if (!self)
		return nil;
	
	self.commitController = controller;

    return self;
}

- (IBAction)forceCommit:(id)sender
{
	[self acceptSheet:sender];
}

@end
