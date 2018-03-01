//
//  PBCreateTagSheet.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/18/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBCreateTagSheet.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"
#import "PBGitRepositoryDocument.h"
#import "PBGitRevSpecifier.h"

@implementation PBCreateTagSheet

#pragma mark -
#pragma mark PBCreateTagSheet

+ (void) beginSheetWithRefish:(id <PBGitRefish>)refish windowController:(PBGitWindowController *)windowController completionHandler:(RJSheetCompletionHandler)handler
{
	PBCreateTagSheet *sheet = [[self alloc] initWithWindowNibName:@"PBCreateTagSheet" windowController:windowController];
	[sheet beginCreateTagSheetAtRefish:refish completionHandler:handler];
}


- (void) beginCreateTagSheetAtRefish:(id <PBGitRefish>)refish completionHandler:(RJSheetCompletionHandler)handler
{
	self.targetRefish = refish;

	[self window];
	[self.errorMessageField setStringValue:@""];

	[self beginSheetWithCompletionHandler:handler];
}



#pragma mark IBActions

- (IBAction) createTag:(id)sender
{
	NSString *tagName = [self.tagNameField stringValue];
	[self.errorMessageField setHidden:YES];

	NSString *refName = [@"refs/tags/" stringByAppendingString:tagName];
	if (![self.repository checkRefFormat:refName]) {
		[self.errorMessageField setStringValue:NSLocalizedString(@"Invalid name", @"Error message for create tag command when the entered name cannot be used as a tag name")];
		[self.errorMessageField setHidden:NO];
		return;
	}

	for (PBGitRevSpecifier *rev in self.repository.branches) {
		NSString *name = [[rev ref] tagName];
		if ([tagName isEqualToString:name]) {
			[self.errorMessageField setStringValue:NSLocalizedString(@"Tag already exists", @"Error message for create tag command when the entered tag name already exists")];
			[self.errorMessageField setHidden:NO];
			return;
		}
	}
	[self acceptSheet:sender];
}


- (IBAction) closeCreateTagSheet:(id)sender
{
	[self cancelSheet:sender];
}



@end
