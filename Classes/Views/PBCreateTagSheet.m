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
#import "PBGitRevSpecifier.h"

@interface PBCreateTagSheet ()

- (void) beginCreateTagSheetAtRefish:(id <PBGitRefish>)refish;

@end


@implementation PBCreateTagSheet

@synthesize repository;
@synthesize targetRefish;

@synthesize tagNameField;
@synthesize tagMessageText;
@synthesize errorMessageField;



#pragma mark -
#pragma mark PBCreateTagSheet

+ (void) beginCreateTagSheetAtRefish:(id <PBGitRefish>)refish inRepository:(PBGitRepository *)repo
{
	PBCreateTagSheet *sheet = [[self alloc] initWithWindowNibName:@"PBCreateTagSheet" forRepo:repo];
	[sheet beginCreateTagSheetAtRefish:refish];
}


- (void) beginCreateTagSheetAtRefish:(id <PBGitRefish>)refish
{
	self.targetRefish  = refish;

	[self window];
	[self.errorMessageField setStringValue:@""];

	[self show];
}



#pragma mark IBActions

- (IBAction) createTag:(id)sender
{
	NSString *tagName = [self.tagNameField stringValue];
	[self.errorMessageField setHidden:YES];

	NSString *refName = [@"refs/tags/" stringByAppendingString:tagName];
	if (![self.repository checkRefFormat:refName]) {
		[self.errorMessageField setStringValue:@"Invalid name"];
		[self.errorMessageField setHidden:NO];
		return;
	}

	for (PBGitRevSpecifier *rev in self.repository.branches) {
		NSString *name = [[rev ref] tagName];
		if ([tagName isEqualToString:name]) {
			[self.errorMessageField setStringValue:@"Tag already exists"];
			[self.errorMessageField setHidden:NO];
			return;
		}
	}


	NSString *message = [self.tagMessageText string];
	[self.repository createTag:tagName message:message atRefish:self.targetRefish];
	
	[self closeCreateTagSheet:sender];
}


- (IBAction) closeCreateTagSheet:(id)sender
{
	[self hide];
}



@end
