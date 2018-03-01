//
//  PBLabelController.m
//  GitX
//
//  Created by Pieter de Bie on 21-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBRefController.h"
#import "PBGitRevisionCell.h"
#import "PBRefMenuItem.h"
#import "PBGitDefaults.h"
#import "PBDiffWindowController.h"
#import "PBGitRevSpecifier.h"
#import "PBGitStash.h"
#import "GitXCommitCopier.h"
#import "PBCommitList.h"
#import "PBGitHistoryController.h"



@implementation PBRefController

- (void)awakeFromNib
{
	[commitList registerForDraggedTypes:[NSArray arrayWithObject:@"PBGitRef"]];
}

#pragma mark Contextual menus

- (NSArray<NSMenuItem *> *) menuItemsForRef:(PBGitRef *)ref
{
	return [PBRefMenuItem defaultMenuItemsForRef:ref inRepository:historyController.repository target:nil];
}

- (NSArray<NSMenuItem *> *) menuItemsForCommits:(NSArray<PBGitCommit *> *)commits
{
	return [PBRefMenuItem defaultMenuItemsForCommits:commits target:nil];
}

- (NSArray<NSMenuItem *> *)menuItemsForRow:(NSInteger)rowIndex
{
	NSArray<PBGitCommit *> *commits = [commitController arrangedObjects];
	if ([commits count] <= rowIndex)
		return nil;

	return [self menuItemsForCommits:@[[commits objectAtIndex:rowIndex]]];
}



# pragma mark Tableview delegate methods

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    
	NSPoint location = [(PBCommitList *)tv mouseDownPoint];
	NSInteger row = [tv rowAtPoint:location];
	NSInteger column = [tv columnAtPoint:location];
	
	PBGitRevisionCell *cell = (PBGitRevisionCell *)[tv preparedCellAtColumn:column row:row];
	PBGitCommit *commit = [[commitController arrangedObjects] objectAtIndex:row];

	int index = -1;
	if ([cell respondsToSelector:@selector(indexAtX:)]) {
		NSRect cellFrame = [tv frameOfCellAtColumn:column row:row];
		CGFloat deltaX = location.x - cellFrame.origin.x;
		index = [cell indexAtX:deltaX];
	}
	
	if (index != -1) {
		PBGitRef *ref = [[commit refs] objectAtIndex:index];
		if ([ref isTag] || [ref isRemoteBranch])
			return NO;

		if ([[[historyController.repository headRef] ref] isEqualToRef:ref])
			return NO;

		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:row], [NSNumber numberWithInt:index], NULL]];
		[pboard declareTypes:[NSArray arrayWithObject:@"PBGitRef"] owner:self];
		[pboard setData:data forType:@"PBGitRef"];
	} else {
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];

		NSString *info = nil;
		if (column == [tv columnWithIdentifier:@"ShortSHAColumn"]) {
			info = [commit shortName];
		} else {
			info = [NSString stringWithFormat:@"%@ (%@)", [commit shortName], [commit subject]];
		}

		[pboard setString:info forType:NSStringPboardType];
	}

	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if (operation == NSTableViewDropAbove)
		return NSDragOperationNone;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	if ([pboard dataForType:@"PBGitRef"])
		return NSDragOperationMove;
	
	return NSDragOperationNone;
}

- (void) dropRef:(NSDictionary *)dropInfo
{
	PBGitRef *ref = [dropInfo objectForKey:@"dragRef"];
	PBGitCommit *oldCommit = [dropInfo objectForKey:@"oldCommit"];
	PBGitCommit *dropCommit = [dropInfo objectForKey:@"dropCommit"];
	if (!ref || ! oldCommit || !dropCommit)
		return;

	if (![historyController.repository updateReference:ref toPointAtCommit:dropCommit])

	[dropCommit addRef:ref];
	[oldCommit removeRef:ref];
	[historyController.commitList reloadData];
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
	if (operation != NSTableViewDropOn)
		return NO;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	NSData *data = [pboard dataForType:@"PBGitRef"];
	if (!data)
		return NO;
	
	NSArray *numbers = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	int oldRow = [[numbers objectAtIndex:0] intValue];
	if (oldRow == row)
		return NO;

	int oldRefIndex = [[numbers objectAtIndex:1] intValue];
	PBGitCommit *oldCommit = [[commitController arrangedObjects] objectAtIndex:oldRow];
	PBGitRef *ref = [[oldCommit refs] objectAtIndex:oldRefIndex];

	PBGitCommit *dropCommit = [[commitController arrangedObjects] objectAtIndex:row];

	NSDictionary *dropInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  ref, @"dragRef",
							  oldCommit, @"oldCommit",
							  dropCommit, @"dropCommit",
							  nil];

	if ([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogAcceptDroppedRef]) {
		[self dropRef:dropInfo];
		return YES;
	}

	NSString *subject = [dropCommit subject];
	if ([subject length] > 99)
		subject = [[subject substringToIndex:99] stringByAppendingString:@"…"];
	NSString *infoText = [NSString stringWithFormat:@"Move the %@ to point to the commit: %@", [ref refishType], subject];

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Move %@: %@", [ref refishType], [ref shortName]]
									 defaultButton:@"Move"
								   alternateButton:@"Cancel"
									   otherButton:nil
						 informativeTextWithFormat:@"%@", infoText];
    [alert setShowsSuppressionButton:YES];

	[alert beginSheetModalForWindow:[historyController.windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(acceptDropInfoAlertDidEnd:returnCode:contextInfo:)
						contextInfo:(__bridge_retained void*)dropInfo];

	return YES;
}

- (void)acceptDropInfoAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn)
		[self dropRef:(__bridge NSDictionary*)contextInfo];

	if ([[alert suppressionButton] state] == NSOnState)
        [PBGitDefaults suppressDialogWarningForDialog:kDialogAcceptDroppedRef];
}

- (void)dealloc {
    historyController = nil;
}

@end
