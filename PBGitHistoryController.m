//
//  PBGitHistoryView.m
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitHistoryController.h"
#import "CWQuickLook.h"
#import "PBGitGrapher.h"
#import "PBGitRevisionCell.h"
#import "PBCommitList.h"
#define QLPreviewPanel NSClassFromString(@"QLPreviewPanel")


@implementation PBGitHistoryController
@synthesize selectedTab, webCommit, rawCommit, gitTree, commitController;

- (void)awakeFromNib
{
	self.selectedTab = [[NSUserDefaults standardUserDefaults] integerForKey:@"Repository Window Selected Tab Index"];;
	[commitController addObserver:self forKeyPath:@"selection" options:(NSKeyValueObservingOptionNew,NSKeyValueObservingOptionOld) context:@"commitChange"];
	[treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeChange"];
	[repository addObserver:self forKeyPath:@"currentBranch" options:0 context:@"branchChange"];
	NSSize cellSpacing = [commitList intercellSpacing];
	cellSpacing.height = 0;
	[commitList setIntercellSpacing:cellSpacing];
	[fileBrowser setTarget:self];
	[fileBrowser setDoubleAction:@selector(openSelectedFile:)];

	if (!repository.currentBranch) {
		[repository reloadRefs];
		[repository readCurrentBranch];
	}
	else
		[repository lazyReload];

	// Set a sort descriptor for the subject column in the history list, as
	// It can't be sorted by default (because it's bound to a PBGitCommit)
	[[commitList tableColumnWithIdentifier:@"subject"] setSortDescriptorPrototype:[[NSSortDescriptor alloc] initWithKey:@"subject" ascending:YES]];
	// Add a menu that allows a user to select which columns to view
	[[commitList headerView] setMenu:[self tableColumnMenu]];
	[historySplitView setTopMin:33.0 andBottomMin:100.0];
	[historySplitView uncollapse];
	[super awakeFromNib];
}

- (void) updateKeys
{
	NSArray* selection = [commitController selectedObjects];
	
	// Remove any references in the QLPanel
	//[[QLPreviewPanel sharedPreviewPanel] setURLs:[NSArray array] currentIndex:0 preservingDisplayState:YES];
	// We have to do this manually, as NSTreeController leaks memory?
	//[treeController setSelectionIndexPaths:[NSArray array]];
	
	if ([selection count] > 0)
		realCommit = [selection objectAtIndex:0];
	else
		realCommit = nil;
	
	self.webCommit = nil;
	self.rawCommit = nil;
	self.gitTree = nil;
	
	switch (self.selectedTab) {
		case 0:	self.webCommit = realCommit;			break;
		case 1:	self.gitTree   = realCommit.tree;	break;
	}
}	


- (void) setSelectedTab: (int) number
{
	selectedTab = number;
	[[NSUserDefaults standardUserDefaults] setInteger:selectedTab forKey:@"Repository Window Selected Tab Index"];
	[self updateKeys];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(NSString *)context isEqualToString: @"commitChange"]) {
		[self updateKeys];
		return;
	}
	else if ([(NSString *)context isEqualToString: @"treeChange"]) {
		[self updateQuicklookForce: NO];
	}
	else if([(NSString *)context isEqualToString:@"branchChange"]) {
		// Reset the sorting
		commitController.sortDescriptors = [NSArray array];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (IBAction) openSelectedFile: sender
{
	NSArray* selectedFiles = [treeController selectedObjects];
	if ([selectedFiles count] == 0)
		return;
	PBGitTree* tree = [selectedFiles objectAtIndex:0];
	NSString* name = [tree tmpFileNameForContents];
	[[NSWorkspace sharedWorkspace] openTempFile:name];
}

- (IBAction) setDetailedView: sender {
	self.selectedTab = 0;
}
- (IBAction) setRawView: sender {
	self.selectedTab = 1;
}
- (IBAction) setTreeView: sender {
	self.selectedTab = 2;
}

- (void)keyDown:(NSEvent*)event
{
	if ([[event charactersIgnoringModifiers] isEqualToString: @"f"] && [event modifierFlags] & NSAlternateKeyMask && [event modifierFlags] & NSCommandKeyMask)
		[superController.window makeFirstResponder: searchField];
	else
		[super keyDown: event];
}

- (void) copyCommitInfo
{
	PBGitCommit *commit = [[commitController selectedObjects] objectAtIndex:0];
	if (!commit)
		return;
	NSString *info = [NSString stringWithFormat:@"%@ (%@)", [[commit realSha] substringToIndex:10], [commit subject]];

	NSPasteboard *a =[NSPasteboard generalPasteboard];
	[a declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[a setString:info forType: NSStringPboardType];
	
}

- (IBAction) toggleQuickView: sender
{
	id panel = [QLPreviewPanel sharedPreviewPanel];
	if ([panel isOpen]) {
		[panel closePanel];
	} else {
		[[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFrontWithEffect:1];
		[self updateQuicklookForce: YES];
	}
}

- (void) updateQuicklookForce: (BOOL) force
{
	if (!force && ![[QLPreviewPanel sharedPreviewPanel] isOpen])
		return;
	
	NSArray* selectedFiles = [treeController selectedObjects];
	
	if ([selectedFiles count] == 0)
		return;
	
	NSMutableArray* fileNames = [NSMutableArray array];
	for (PBGitTree* tree in selectedFiles) {
		NSString* s = [tree tmpFileNameForContents];
		if (s)
			[fileNames addObject:[NSURL fileURLWithPath: s]];
	}
	
	[[QLPreviewPanel sharedPreviewPanel] setURLs:fileNames currentIndex:0 preservingDisplayState:YES];
	
}

- (IBAction) refresh: sender
{
	[repository reloadRefs];
	[repository.revisionList reload];
}

- (void) updateView
{
	[self refresh:nil];
}

- (NSResponder *)firstResponder;
{
	return commitList;
}

- (void) selectCommit: (NSString*) commit
{
	NSPredicate* selection = [NSPredicate predicateWithFormat:@"realSha == %@", commit];
	NSArray* selectedCommits = [repository.revisionList.commits filteredArrayUsingPredicate:selection];
	[commitController setSelectedObjects: selectedCommits];
	int index = [[commitController selectionIndexes] firstIndex];
	[commitList scrollRowToVisible: index];
}

- (BOOL) hasNonlinearPath
{
	return [commitController filterPredicate] || [[commitController sortDescriptors] count] > 0;
}

- (void) removeView
{
	[webView close];
	[commitController removeObserver:self forKeyPath:@"selection"];
	[treeController removeObserver:self forKeyPath:@"selection"];
	[repository removeObserver:self forKeyPath:@"currentBranch"];

	[super removeView];
}

#pragma mark Table Column Methods
- (NSMenu *)tableColumnMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Table columns menu"];
	for (NSTableColumn *column in [commitList tableColumns]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:[[column headerCell] stringValue]];
		[item bind:@"value"
		  toObject:column
	   withKeyPath:@"hidden"
		   options:[NSDictionary dictionaryWithObject:@"NSNegateBoolean" forKey:NSValueTransformerNameBindingOption]];
		[menu addItem:item];
	}
	return menu;
}

#pragma mark Tree Context Menu Methods

- (void)showCommitsFromTree:(id)sender
{
	// TODO: Enable this from webview as well!

	NSMutableArray *filePaths = [NSMutableArray arrayWithObjects:@"HEAD", @"--", NULL];
	[filePaths addObjectsFromArray:[sender representedObject]];

	PBGitRevSpecifier *revSpec = [[PBGitRevSpecifier alloc] initWithParameters:filePaths];

	repository.currentBranch = [repository addBranch:revSpec];
}

- (void)showInFinderAction:(id)sender
{
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	NSString *path;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	for (NSString *filePath in [sender representedObject]) {
		path = [workingDirectory stringByAppendingPathComponent:filePath];
		[ws selectFile: path inFileViewerRootedAtPath:path];
	}

}

- (void)openFilesAction:(id)sender
{
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	NSString *path;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	for (NSString *filePath in [sender representedObject]) {
		path = [workingDirectory stringByAppendingPathComponent:filePath];
		[ws openFile:path];
	}
}


- (NSMenu *)contextMenuForTreeView
{
	NSArray *filePaths = [[treeController selectedObjects] valueForKey:@"fullPath"];

	NSMenu *menu = [[NSMenu alloc] init];
	for (NSMenuItem *item in [self menuItemsForPaths:filePaths])
		[menu addItem:item];
	return menu;
}

- (NSArray *)menuItemsForPaths:(NSArray *)paths
{
	BOOL multiple = [paths count] != 1;
	NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:multiple? @"Show history of files" : @"Show history of file"
														 action:@selector(showCommitsFromTree:)
												 keyEquivalent:@""];
	NSMenuItem *finderItem = [[NSMenuItem alloc] initWithTitle:@"Show in Finder"
														action:@selector(showInFinderAction:)
												 keyEquivalent:@""];
	NSMenuItem *openFilesItem = [[NSMenuItem alloc] initWithTitle:multiple? @"Open Files" : @"Open File"
														   action:@selector(openFilesAction:)
													keyEquivalent:@""];

	NSArray *menuItems = [NSArray arrayWithObjects:historyItem, finderItem, openFilesItem, nil];
	for (NSMenuItem *item in menuItems) {
		[item setTarget:self];
		[item setRepresentedObject:paths];
	}

	return menuItems;
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
	return TRUE;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
	int index = [[splitView subviews] indexOfObject:subview];
	// this method (and canCollapse) are called by the splitView to decide how to collapse on double-click
	// we compare our two subviews, so that always the smaller one is collapsed.
	if([[[splitView subviews] objectAtIndex:index] frame].size.height < [[[splitView subviews] objectAtIndex:((index+1)%2)] frame].size.height) {
		return TRUE;
	}
	return FALSE;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	return proposedMin + historySplitView.topViewMin;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	if(offset == 1)
		return proposedMax - historySplitView.bottomViewMin;
	return [sender frame].size.height;
}

@end
