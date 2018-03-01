//
//  PBWebChangesController.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebChangesController.h"
#import "PBGitIndex.h"

@interface PBWebChangesController () <WebEditingDelegate, WebUIDelegate>
@end

@implementation PBWebChangesController

- (void) awakeFromNib
{
	selectedFile = nil;
	selectedFileIsCached = NO;

	startFile = @"commit";
	[super awakeFromNib];

	[unstagedFilesController addObserver:self forKeyPath:@"selection" options:0 context:@"UnstagedFileSelected"];
	[stagedFilesController addObserver:self forKeyPath:@"selection" options:0 context:@"cachedFileSelected"];

	self.view.editingDelegate = self;
	self.view.UIDelegate = self;
}

- (void)closeView
{
	[[self script] removeWebScriptKey:@"Index"];
	[unstagedFilesController removeObserver:self forKeyPath:@"selection"];
	[stagedFilesController removeObserver:self forKeyPath:@"selection"];

	[super closeView];
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
	otherController = object == unstagedFilesController ? stagedFilesController : unstagedFilesController;
	NSUInteger count = [object selectedObjects].count;
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
	selectedFileIsCached = object == stagedFilesController;

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

	id script = self.view.windowScriptObject;
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

- (void) discardHunk:(NSString *)hunk
{
    [controller.index applyPatch:hunk stage:NO reverse:YES];
    [self refresh];
}

- (void) discardHunkAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn)
		[self discardHunk:(__bridge NSString*)contextInfo];
}

- (void)discardHunk:(NSString *)hunk altKey:(BOOL)altKey
{
	if (!altKey) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Discard hunk", @"Title of dialogue asking whether the user really wanted to press the Discard button on a hunk in the changes view")
                                         defaultButton:nil
                                       alternateButton:NSLocalizedString(@"Cancel", @"Cancel (discarding a hunk in the changes view)")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Are you sure you wish to discard the changes in this hunk?\n\nYou cannot undo this operation.", @"Asks whether the user really wants to discard a hunk in changes view after pressing the Discard Hunk button")];
		[alert beginSheetModalForWindow:[[controller view] window]
                          modalDelegate:self
                         didEndSelector:@selector(discardHunkAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:(__bridge_retained void*)hunk];
	} else {
        [self discardHunk:hunk];
    }
}

- (void) setStateMessage:(NSString *)state
{
	id script = self.view.windowScriptObject;
	[script callWebScriptMethod:@"setState" withArguments: [NSArray arrayWithObject:state]];
}

-(void)copy: (NSString *)text{
	NSArray *lines = [text componentsSeparatedByString:@"\n"];
	NSMutableArray *processedLines = [NSMutableArray arrayWithCapacity:lines.count -1];
	for (int i = 0; i < lines.count; i++) {
		NSString *line = [lines objectAtIndex:i];
		if (line.length>0) {
			[processedLines addObject:[line substringFromIndex:1]];
		} else {
			[processedLines addObject:line];
		}
	}
	NSString *result = [processedLines componentsJoinedByString:@"\n"];
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[[NSPasteboard generalPasteboard] setString:result forType:NSStringPboardType];
}

- (BOOL)webView:(WebView *)webView
	validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
	defaultValidation:(BOOL)defaultValidation
{
	if (item.action == @selector(copy:)) {
		return YES;
	} else {
		return defaultValidation;
	}
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)selector
{
	if (selector == @selector(copy:)) {
		[self.script callWebScriptMethod:@"copy" withArguments:@[]];
		return YES;
	} else {
		return NO;
	}
}

@end
