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
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBGitDefaults.h"
#import "PBDiffWindowController.h"
#import "PBGitRevSpecifier.h"

#define kDialogAcceptDroppedRef @"Accept Dropped Ref"
#define kDialogConfirmPush @"Confirm Push"
#define kDialogDeleteRef @"Delete Ref"



@implementation PBRefController

- (void)awakeFromNib
{
	[commitList registerForDraggedTypes:[NSArray arrayWithObject:@"PBGitRef"]];
}


#pragma mark Fetch

- (void) fetchRemote:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	if ([refish refishType] == kGitXCommitType)
		return;

	[historyController.repository beginFetchFromRemoteForRef:refish];
}


#pragma mark Pull

- (void) pullRemote:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[historyController.repository beginPullFromRemote:nil forRef:refish];
}


#pragma mark Push

- (void)showConfirmPushRefSheet:(PBGitRef *)ref remote:(PBGitRef *)remoteRef
{
	if ((!ref && !remoteRef)
		|| (ref && ![ref isBranch] && ![ref isRemoteBranch] && ![ref isTag])
		|| (remoteRef && !([remoteRef refishType] == kGitXRemoteType)))
		return;

	if ([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogConfirmPush]) {
		[historyController.repository beginPushRef:ref toRemote:remoteRef];
		return;
	}

	NSString *description = nil;
	if (ref && remoteRef)
		description = [NSString stringWithFormat:@"Push %@ '%@' to remote %@", [ref refishType], [ref shortName], [remoteRef remoteName]];
	else if (ref)
		description = [NSString stringWithFormat:@"Push %@ '%@' to default remote", [ref refishType], [ref shortName]];
	else
		description = [NSString stringWithFormat:@"Push updates to remote %@", [remoteRef remoteName]];

    NSString * sdesc = [NSString stringWithFormat:@"p%@", [description substringFromIndex:1]]; 
	NSAlert *alert = [NSAlert alertWithMessageText:description
									 defaultButton:@"Push"
								   alternateButton:@"Cancel"
									   otherButton:nil
						 informativeTextWithFormat:@"Are you sure you want to %@?", sdesc];
    [alert setShowsSuppressionButton:YES];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	if (ref)
		[info setObject:ref forKey:kGitXBranchType];
	if (remoteRef)
		[info setObject:remoteRef forKey:kGitXRemoteType];

	[alert beginSheetModalForWindow:[historyController.repository.windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(confirmPushRefSheetDidEnd:returnCode:contextInfo:)
						contextInfo:(__bridge_retained void*)info];
}

- (void)confirmPushRefSheetDidEnd:(NSAlert *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[sheet window] orderOut:nil];

	if ([[sheet suppressionButton] state] == NSOnState)
        [PBGitDefaults suppressDialogWarningForDialog:kDialogConfirmPush];

	if (returnCode == NSAlertDefaultReturn) {
		PBGitRef *ref = [(__bridge NSDictionary *)contextInfo objectForKey:kGitXBranchType];
		PBGitRef *remoteRef = [(__bridge NSDictionary *)contextInfo objectForKey:kGitXRemoteType];

		[historyController.repository beginPushRef:ref toRemote:remoteRef];
	}
}

- (void) pushUpdatesToRemote:(PBRefMenuItem *)sender
{
	PBGitRef *remoteRef = [(PBGitRef *)[sender refish] remoteRef];

	[self showConfirmPushRefSheet:nil remote:remoteRef];
}

- (void) pushDefaultRemoteForRef:(PBRefMenuItem *)sender
{
	PBGitRef *ref = (PBGitRef *)[sender refish];

	[self showConfirmPushRefSheet:ref remote:nil];
}

- (void) pushToRemote:(PBRefMenuItem *)sender
{
	PBGitRef *ref = (PBGitRef *)[sender refish];
	NSString *remoteName = [sender representedObject];
	PBGitRef *remoteRef = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:remoteName]];

	[self showConfirmPushRefSheet:ref remote:remoteRef];
}


#pragma mark Merge

- (void) merge:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[historyController.repository mergeWithRefish:refish];
}


#pragma mark Checkout

- (void) checkout:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[historyController.repository checkoutRefish:refish];
}


#pragma mark Cherry Pick

- (void) cherryPick:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[historyController.repository cherryPickRefish:refish];
}


#pragma mark Rebase

- (void) rebaseHeadBranch:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];

	[historyController.repository rebaseBranch:nil onRefish:refish];
}


#pragma mark Create Branch

- (void) createBranch:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[PBCreateBranchSheet beginCreateBranchSheetAtRefish:refish inRepository:historyController.repository];
}


#pragma mark Copy info

- (void) copySHA:(PBRefMenuItem *)sender
{
	PBGitCommit *commit = nil;
	if ([[sender refish] refishType] == kGitXCommitType)
		commit = (PBGitCommit *)[sender refish];
	else
		commit = [historyController.repository commitForRef:[sender refish]];

	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pasteboard setString:[commit realSha] forType:NSStringPboardType];
}


- (void) copyShortSHA:(PBRefMenuItem *)sender
{
	PBGitCommit *commit = nil;
	if ([[sender refish] refishType] == kGitXCommitType)
		commit = (PBGitCommit *)[sender refish];
	else
		commit = [historyController.repository commitForRef:[sender refish]];
    
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pasteboard setString:[commit shortName] forType:NSStringPboardType];
}


- (void) copyPatch:(PBRefMenuItem *)sender
{
	PBGitCommit *commit = nil;
	if ([[sender refish] refishType] == kGitXCommitType)
		commit = (PBGitCommit *)[sender refish];
	else
		commit = [historyController.repository commitForRef:[sender refish]];

	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pasteboard setString:[commit patch] forType:NSStringPboardType];
}


#pragma mark Diff

- (void) diffWithHEAD:(PBRefMenuItem *)sender
{
	PBGitCommit *commit = nil;
	if ([[sender refish] refishType] == kGitXCommitType)
		commit = (PBGitCommit *)[sender refish];
	else
		commit = [historyController.repository commitForRef:[sender refish]];

	[PBDiffWindowController showDiffWindowWithFiles:nil fromCommit:commit diffCommit:nil];
}

#pragma mark Tags

- (void) createTag:(PBRefMenuItem *)sender
{
	id <PBGitRefish> refish = [sender refish];
	[PBCreateTagSheet beginCreateTagSheetAtRefish:refish inRepository:historyController.repository];
}

- (void) showTagInfoSheet:(PBRefMenuItem *)sender
{
	if ([[sender refish] refishType] != kGitXTagType)
		return;

	NSError *error = nil;
	NSString *tagName = [(PBGitRef *)[sender refish] tagName];
	NSString *tagRef = [@"refs/tags/" stringByAppendingString:tagName];
	GTObject *object = [historyController.repository.gtRepo lookUpObjectByRevParse:tagRef error:&error];
	if (!object) {
		NSLog(@"Couldn't look up ref %@:%@", tagRef, [error debugDescription]);
		return;
	}
	NSString* title = [NSString stringWithFormat:@"Info for tag: %@", tagName];
	NSString* info = @"";
	if ([object isKindOfClass:[GTTag class]]) {
		GTTag *tag = (GTTag*)object;
		info = tag.message;
	}
	[historyController.repository.windowController showMessageSheet:title infoText:info];
}


#pragma mark Remove a branch, remote or tag

- (void)showDeleteRefSheet:(PBRefMenuItem *)sender
{
	if ([[sender refish] refishType] == kGitXCommitType)
		return;

	PBGitRef *ref = (PBGitRef *)[sender refish];

	if ([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogDeleteRef]) {
		[historyController.repository deleteRef:ref];
		return;
	}

	NSString *ref_desc = [NSString stringWithFormat:@"%@ '%@'", [ref refishType], [ref shortName]];

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Delete %@?", ref_desc]
									 defaultButton:@"Delete"
								   alternateButton:@"Cancel"
									   otherButton:nil
						 informativeTextWithFormat:@"Are you sure you want to remove the %@?", ref_desc];
    [alert setShowsSuppressionButton:YES];
	
	[alert beginSheetModalForWindow:[historyController.repository.windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteRefSheetDidEnd:returnCode:contextInfo:)
						contextInfo:(__bridge_retained void*)ref];
}

- (void)deleteRefSheetDidEnd:(NSAlert *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    [[sheet window] orderOut:nil];

	if ([[sheet suppressionButton] state] == NSOnState)
        [PBGitDefaults suppressDialogWarningForDialog:kDialogDeleteRef];

	if (returnCode == NSAlertDefaultReturn) {
		PBGitRef *ref = (__bridge PBGitRef *)contextInfo;
		[historyController.repository deleteRef:ref];
	}
}



#pragma mark Contextual menus

- (NSArray *) menuItemsForRef:(PBGitRef *)ref
{
	return [PBRefMenuItem defaultMenuItemsForRef:ref inRepository:historyController.repository target:self];
}

- (NSArray *) menuItemsForCommit:(PBGitCommit *)commit
{
	return [PBRefMenuItem defaultMenuItemsForCommit:commit target:self];
}

- (NSArray *)menuItemsForRow:(NSInteger)rowIndex
{
	NSArray *commits = [commitController arrangedObjects];
	if ([commits count] <= rowIndex)
		return nil;

	return [self menuItemsForCommit:[commits objectAtIndex:rowIndex]];
}


# pragma mark Tableview delegate methods

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    
	NSPoint location = [(PBCommitList *)tv mouseDownPoint];
	int row = [tv rowAtPoint:location];
	int column = [tv columnAtPoint:location];
	int subjectColumn = [tv columnWithIdentifier:@"SubjectColumn"];
	if (column != subjectColumn)
		return NO;
	
	PBGitRevisionCell *cell = (PBGitRevisionCell *)[tv preparedCellAtColumn:column row:row];
	NSRect cellFrame = [tv frameOfCellAtColumn:column row:row];
	
	int index = [cell indexAtX:(location.x - cellFrame.origin.x)];
	
	if (index == -1)
		return NO;

	PBGitRef *ref = [[[cell objectValue] refs] objectAtIndex:index];
	if ([ref isTag] || [ref isRemoteBranch])
		return NO;

	if ([[[historyController.repository headRef] ref] isEqualToRef:ref])
		return NO;
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:row], [NSNumber numberWithInt:index], NULL]];
	[pboard declareTypes:[NSArray arrayWithObject:@"PBGitRef"] owner:self];
	[pboard setData:data forType:@"PBGitRef"];
	
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

	int retValue = 1;
	[historyController.repository outputForArguments:[NSArray arrayWithObjects:@"update-ref", @"-mUpdate from GitX", [ref ref], [dropCommit realSha], NULL] retValue:&retValue];
	if (retValue)
		return;

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

	[alert beginSheetModalForWindow:[historyController.repository.windowController window]
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
