//
//  PBQLOutlineView.m
//  GitX
//
//  Created by Pieter de Bie on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBQLOutlineView.h"


@implementation PBQLOutlineView

- initWithCoder: (NSCoder *) coder
{
	id a = [super initWithCoder:coder];
	[a setDataSource: a];
	[a registerForDraggedTypes: [NSArray arrayWithObject:NSFilesPromisePboardType]];
	return a;
}

/* Needed to drag outside application */
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL) local
{
	return NSDragOperationCopy;
}

- (void) keyDown: (NSEvent *) event
{
	if ([[event characters] isEqualToString:@" "]) {
		[controller toggleQuickView:self];
		return;
	}

	[super keyDown:event];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *) pb
{
	NSMutableArray* fileNames = [NSMutableArray array];
	for (id tree in items)
		[fileNames addObject: [[[tree representedObject] path] pathExtension]];

	[pb declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
    [pb setPropertyList:fileNames forType:NSFilesPromisePboardType];

	return YES;
}

- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items
{
	NSMutableArray* fileNames = [NSMutableArray array];
	for (id obj in items) {
		PBGitTree* tree = [obj representedObject];
		[fileNames addObject: [tree path]];
		[tree saveToFolder:[dropDestination path]];
	}
	return fileNames;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSRightMouseDown)
	{
		// get the current selections for the outline view.
		NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];

		// select the row that was clicked before showing the menu for the event
		NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		int row = [self rowAtPoint:mousePoint];

		// figure out if the row that was just clicked on is currently selected
		if ([selectedRowIndexes containsIndex:row] == NO)
			[self selectRow:row byExtendingSelection:NO];
	}

	return [controller contextMenuForTreeView];
}

/* Implemented to satisfy datasourcee protocol */
- (BOOL) outlineView: (NSOutlineView *)ov
         isItemExpandable: (id)item { return NO; }

- (NSInteger)  outlineView: (NSOutlineView *)ov
         numberOfChildrenOfItem:(id)item { return 0; }

- (id)   outlineView: (NSOutlineView *)ov
         child:(NSInteger)index
         ofItem:(id)item { return nil; }

- (id)   outlineView: (NSOutlineView *)ov
         objectValueForTableColumn:(NSTableColumn*)col
         byItem:(id)item { return nil; }
@end
