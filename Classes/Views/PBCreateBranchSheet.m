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
#import "PBGitRepositoryDocument.h"

@implementation PBCreateBranchSheet

#pragma mark -
#pragma mark PBCreateBranchSheet

+ (void)beginSheetWithRefish:(id <PBGitRefish>)ref windowController:(PBGitWindowController *)windowController
{
	[self beginSheetWithRefish:ref windowController:windowController completionHandler:nil];
}

+ (void)beginSheetWithRefish:(id <PBGitRefish>)ref windowController:(PBGitWindowController *)windowController completionHandler:(RJSheetCompletionHandler)handler {
	PBCreateBranchSheet *sheet = [[self alloc] initWithWindowController:windowController atRefish:ref];
	[sheet beginCreateBranchSheetAtRefish:ref completionHandler:handler];
}



- (id)initWithWindowController:(PBGitWindowController *)windowController atRefish:(id<PBGitRefish>)ref
{
	NSParameterAssert(windowController != nil);
	NSParameterAssert(ref != nil);

	self = [super initWithWindowNibName:@"PBCreateBranchSheet" windowController:windowController];
	if (!self)
		return nil;

	self.startRefish = ref;
	
	return self;
}

- (void) beginCreateBranchSheetAtRefish:(id <PBGitRefish>)ref completionHandler:(RJSheetCompletionHandler)handler
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
	[self beginSheetWithCompletionHandler:handler];
}



#pragma mark IBActions

- (IBAction) createBranch:(id)sender
{
	NSString *name = [self.branchNameField stringValue];
	self.selectedRef = [PBGitRef refFromString:[kGitXBranchRefPrefix stringByAppendingString:name]];

	if (![self.repository checkRefFormat:[self.selectedRef ref]]) {
		[self.errorMessageField setStringValue:NSLocalizedString(@"Invalid name", @"Error message for create branch command when the entered name cannot be used as a branch name")];
		[self.errorMessageField setHidden:NO];
		return;
	}

	if ([self.repository refExists:self.selectedRef]) {
		[self.errorMessageField setStringValue:NSLocalizedString(@"Branch already exists", @"Error message for create branch command")];
		[self.errorMessageField setHidden:NO];
		return;
	}

	[self acceptSheet:sender];
}


- (IBAction) closeCreateBranchSheet:(id)sender
{
	[self cancelSheet:sender];
}

@end
