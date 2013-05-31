//
//  PBCreateBranchSheet.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/13/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBCreateBranchSheet.h"
#import "PBGitRepository.h"
#import "PBGitDefaults.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"

@interface PBCreateBranchSheet ()

- (void) beginCreateBranchSheetAtRefish:(id <PBGitRefish>)ref inRepository:(PBGitRepository *)repo;
- (id) initWithRepositoryWindow:(PBGitWindowController*)parent atRefish:(id <PBGitRefish>)ref;

@end


@implementation PBCreateBranchSheet


@synthesize repository;
@synthesize startRefish;
@synthesize shouldCheckoutBranch;

@synthesize branchNameField;
@synthesize errorMessageField;



#pragma mark -
#pragma mark PBCreateBranchSheet

+ (void) beginCreateBranchSheetAtRefish:(id <PBGitRefish>)ref inRepository:(PBGitRepository *)repo
{
	PBCreateBranchSheet *sheet = [[self alloc] initWithRepositoryWindow:repo.windowController
															   atRefish:ref];
	[sheet beginCreateBranchSheetAtRefish:ref inRepository:repo];
}

- (id) initWithRepositoryWindow:(PBGitWindowController *)parent atRefish:(id<PBGitRefish>)ref
{
	self = [super initWithWindowNibName:@"PBCreateBranchSheet" forRepo:parent.repository];
	if (!self)
		return nil;
	
	self.repository = parent.repository;
	self.startRefish = ref;
	
	return self;
}

- (void) beginCreateBranchSheetAtRefish:(id <PBGitRefish>)ref inRepository:(PBGitRepository *)repo
{
	[self window]; // loads the window (if it wasn't already)
	[self.errorMessageField setStringValue:@""];
	self.shouldCheckoutBranch = [PBGitDefaults shouldCheckoutBranch];

	// when creating a local branch tracking a remote branch preset the branch name to the 	name of the remote branch
	if ([self.startRefish refishType] == kGitXRemoteBranchType) {
		NSMutableArray *components = [[[self.startRefish shortName] componentsSeparatedByString:@"/"] mutableCopy];
		if ([components count] > 1) {
			[components removeObjectAtIndex:0];
			NSString *branchName = [components componentsJoinedByString:@"/"];
			[self.branchNameField setStringValue:branchName];
		}
	}
	
	[self show];
}



#pragma mark IBActions

- (IBAction) createBranch:(id)sender
{
	NSString *name = [self.branchNameField stringValue];
	PBGitRef *ref = [PBGitRef refFromString:[kGitXBranchRefPrefix stringByAppendingString:name]];

	if (![self.repository checkRefFormat:[ref ref]]) {
		[self.errorMessageField setStringValue:@"Invalid name"];
		[self.errorMessageField setHidden:NO];
		return;
	}

	if ([self.repository refExists:ref]) {
		[self.errorMessageField setStringValue:@"Branch already exists"];
		[self.errorMessageField setHidden:NO];
		return;
	}

	[self closeCreateBranchSheet:self];

	[self.repository createBranch:name atRefish:self.startRefish];
	
	[PBGitDefaults setShouldCheckoutBranch:self.shouldCheckoutBranch];

	if (self.shouldCheckoutBranch)
		[self.repository checkoutRefish:ref];
}


- (IBAction) closeCreateBranchSheet:(id)sender
{
	[self hide];
}

@end
