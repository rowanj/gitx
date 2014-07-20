//
//  GitXTextFieldCell.m
//  GitX
//
//  Created by Nathan Kinsinger on 8/27/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "GitXTextFieldCell.h"
#import "PBGitCommit.h"
#import "PBRefController.h"
#import "PBRefContextDelegate.h"


@implementation GitXTextFieldCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// disables the cell's selection highlight
	return nil;
}

- (NSMenu *)menuForEvent:(NSEvent *)anEvent inRect:(NSRect)cellFrame ofView:(NSTableView *)commitList
{
	NSInteger rowIndex = [commitList rowAtPoint:(cellFrame.origin)];
	NSArray *items = [contextMenuDelegate menuItemsForRow:rowIndex];
	if (!items)
		return nil;

	NSMenu *menu = [[NSMenu alloc] init];
	[menu setAutoenablesItems:NO];
	for (NSMenuItem *item in items)
		[menu addItem:item];

	return menu;
}

@end
