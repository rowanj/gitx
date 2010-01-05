//
//  PBWebChangesController.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebChangesController.h"
#import "PBGitIndexController.h"
#import "PBGitIndex.h"

@implementation PBWebChangesController

- (void) awakeFromNib
{
	selectedFile = nil;
	selectedFileIsCached = NO;

	startFile = @"commit";
	[super awakeFromNib];

	[unstagedFilesController addObserver:self forKeyPath:@"selection" options:0 context:@"UnstagedFileSelected"];
	[cachedFilesController addObserver:self forKeyPath:@"selection" options:0 context:@"cachedFileSelected"];
}

- (void) didLoad
{
	[[self script] setValue:controller.index forKey:@"Index"];
	[self refresh];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	NSArrayController *otherController;
	otherController = object == unstagedFilesController ? cachedFilesController : unstagedFilesController;
	int count = [[object selectedObjects] count];
	if (count == 0) {
		if([[otherController selectedObjects] count] == 0 && selectedFile) {
			selectedFile = nil;
			selectedFileIsCached = NO;
			[self refresh];
		}
		return;
	}

	// TODO: Move this to commitcontroller
	[otherController setSelectionIndexes:[NSIndexSet indexSet]];

	if (count > 1) {
		[self showMultiple: [object selectedObjects]];
		return;
	}

	selectedFile = [[object selectedObjects] objectAtIndex:0];
	selectedFileIsCached = object == cachedFilesController;

	[self refresh];
}

- (void) showMultiple: (NSArray *)objects
{
	[[self script] callWebScriptMethod:@"showMultipleFilesSelection" withArguments:[NSArray arrayWithObject:objects]];
}

- (void) refresh
{
	if (!finishedLoading)
		return;

	id script = [view windowScriptObject];
	[script callWebScriptMethod:@"showFileChanges"
		      withArguments:[NSArray arrayWithObjects:selectedFile ?: (id)[NSNull null],
				     [NSNumber numberWithBool:selectedFileIsCached], nil]];
}

- (void)stageHunk:(NSString *)hunk reverse:(BOOL)reverse
{
	[controller.index applyPatch:hunk stage:YES reverse:reverse];
	// FIXME: Don't need a hard refresh

	[self refresh];
}

- (void)discardHunk:(NSString *)hunk altKey:(BOOL)altKey
{
	int ret = NSAlertDefaultReturn;
	if (!altKey) {
		ret = [[NSAlert alertWithMessageText:@"Discard hunk"
			defaultButton:nil
			alternateButton:@"Cancel"
			otherButton:nil
			informativeTextWithFormat:@"Are you sure you wish to discard the changes in this hunk?\n\nYou cannot undo this operation."] runModal];
	}

	if (ret == NSAlertDefaultReturn) {
		[controller.index applyPatch:hunk stage:NO reverse:YES];
		[self refresh];
	}
}

- (void) setStateMessage:(NSString *)state
{
	id script = [view windowScriptObject];
	[script callWebScriptMethod:@"setState" withArguments: [NSArray arrayWithObject:state]];
}

@end
