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
			commitController:(PBGitCommitController *)controller;
{
	PBCommitHookFailedSheet* sheet = [[self alloc] initWithWindowNibName:@"PBCommitHookFailedSheet"
														   andController:controller];
	[sheet beginMessageSheetWithMessageText:message
								   infoText:info];
}

- (id)initWithWindowNibName:(NSString*)windowNibName
			  andController:(PBGitCommitController*)controller;
{
    self = [self initWithWindowNibName:windowNibName forRepo:controller.repository];
	if (!self)
		return nil;
	
	self.commitController = controller;

    return self;
}

- (IBAction)forceCommit:(id)sender
{
	PBGitCommitController *controller = self.commitController;
	[self closeMessageSheet:sender];
	[controller forceCommit:sender];
}

@end
