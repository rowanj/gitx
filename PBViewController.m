//
//  PBViewController.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBViewController.h"


@implementation PBViewController

@synthesize repository, viewToolbar;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	NSString *nibName = [[[self class] description] stringByReplacingOccurrencesOfString:@"Controller"
																			  withString:@"View"];
	if(self = [self initWithNibName:nibName bundle:nil]) {
		repository = theRepository;
		superController = controller;
	}
	
	return self;
}

- (void) removeView
{
	[self unbind:@"repository"];
	[[self view] removeFromSuperview];	// remove the current view
}

- (void) awakeFromNib
{
}

// This is called when the view is displayed again; it 
// should be updated to show the most recent information
- (void) updateView
{
}

- (NSResponder *)firstResponder;
{
	return nil;
}
@end
