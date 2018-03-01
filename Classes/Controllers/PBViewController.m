//
//  PBViewController.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBViewController.h"

@interface PBViewController () {
	BOOL _hasViewLoaded;
}
@end

@implementation PBViewController

@synthesize repository=repository;
@synthesize windowController=superController;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	NSString *nibName = [[[self class] description] stringByReplacingOccurrencesOfString:@"Controller"
																			  withString:@"View"];
	self = [self initWithNibName:nibName bundle:nil];
	if (!self) return nil;

	repository = theRepository;
	superController = controller;
	
	return self;
}

- (void)closeView
{
	[self unbind:@"repository"];
	if (_hasViewLoaded)
		[[self view] removeFromSuperview];	// remove the current view
}

- (void)awakeFromNib
{
	_hasViewLoaded = YES;
}

- (NSResponder *)firstResponder;
{
	return nil;
}

- (IBAction) refresh: sender
{
}

// The next methods should be implemented in the subclass if necessary
- (void)updateView
{
}

- (void)viewLoaded
{
}

@end
