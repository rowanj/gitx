//
//  PBRefMenuItem.m
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBRefMenuItem.h"
#import "PBGitRepository.h"
#import "PBGitRevSpecifier.h"

@implementation PBRefMenuItem
@synthesize refishs;

+ (PBRefMenuItem *) itemWithTitle:(NSString *)title action:(SEL)selector enabled:(BOOL)isEnabled
{
	if (!isEnabled)
		selector = nil;

	PBRefMenuItem *item = [[PBRefMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	[item setEnabled:isEnabled];
	return item;
}


+ (PBRefMenuItem *) separatorItem
{
	PBRefMenuItem *item = (PBRefMenuItem *)[super separatorItem];
	return item;
}


+ (NSArray<NSMenuItem *> *) defaultMenuItemsForStashRef:(PBGitRef *)ref inRepository:(PBGitRepository *)repo target:(id)target
{
    NSMutableArray *items = [NSMutableArray array];
	NSString *targetRefName = [ref shortName];
    BOOL isCleanWorkingCopy = YES;
    
    // pop
    NSString *stashPopTitle = [NSString stringWithFormat:NSLocalizedString(@"Pop %@", @"Contextual Menu Item to pop the selected stash ref"), targetRefName];
    [items addObject:[PBRefMenuItem itemWithTitle:stashPopTitle action:@selector(stashPop:) enabled:isCleanWorkingCopy]];
    
    // apply
    NSString *stashApplyTitle = [NSString stringWithFormat:NSLocalizedString(@"Apply %@", @"Contextual Menu Item to apply the selected stash ref"), targetRefName];
    [items addObject:[PBRefMenuItem itemWithTitle:stashApplyTitle action:@selector(stashApply:) enabled:YES]];
    
    // view diff
    NSString *stashDiffTitle = @"View Diff";
    [items addObject:[PBRefMenuItem itemWithTitle:stashDiffTitle action:@selector(stashViewDiff:) enabled:YES]];

    [items addObject:[PBRefMenuItem separatorItem]];

    // drop
    NSString *stashDropTitle = [NSString stringWithFormat:NSLocalizedString(@"Drop %@", @"Contextual Menu Item to drop the selected stash ref"), targetRefName];
    [items addObject:[PBRefMenuItem itemWithTitle:stashDropTitle action:@selector(stashDrop:) enabled:YES]];
    
	for (PBRefMenuItem *item in items) {
		item.target = target;
		item.refishs = @[ref];
	}
    
	return items;
}


+ (NSArray<NSMenuItem *> *) defaultMenuItemsForRef:(PBGitRef *)ref inRepository:(PBGitRepository *)repo target:(id)target
{
	if (!ref || !repo) {
		return nil;
	}
	
    if (ref.isStash) {
        return [self defaultMenuItemsForStashRef:ref inRepository:repo target:target];
    }

	NSString *refName = ref.shortName;

	PBGitRef *headRef = repo.headRef.ref;
	NSString *headRefName = headRef.shortName;

	BOOL isHead = [ref isEqualToRef:headRef];
	BOOL isOnHeadBranch = isHead ? YES : [repo isRefOnHeadBranch:ref];
	BOOL isDetachedHead = (isHead && [headRefName isEqualToString:@"HEAD"]);

	NSString *remoteName = ref.remoteName;
	if (!remoteName && ref.isBranch) {
		remoteName = [[repo remoteRefForBranch:ref error:NULL] remoteName];
	}
	BOOL hasRemote = (remoteName ? YES : NO);
	BOOL isRemote = (ref.isRemote && !ref.isRemoteBranch);

	NSMutableArray *items = [NSMutableArray array];
	if (!isRemote) {
		// checkout ref
		NSString *checkoutTitle = [NSString stringWithFormat:NSLocalizedString(@"Checkout “%@”", @"Contextual Menu Item to check out the selected ref"), refName];
		[items addObject:[PBRefMenuItem itemWithTitle:checkoutTitle action:@selector(checkout:) enabled:!isHead]];
		[items addObject:[PBRefMenuItem separatorItem]];

		// create branch
		NSString *createBranchTitle = ref.isRemoteBranch
			? [NSString stringWithFormat:NSLocalizedString(@"Create Branch tracking “%@”…", @"Contextual Menu Item to create a branch tracking the selected remote branch"), refName]
			: NSLocalizedString(@"Create Branch…", @"Contextual Menu Item to create a new branch at the selected ref");
		[items addObject:[PBRefMenuItem itemWithTitle:createBranchTitle action:@selector(createBranch:) enabled:YES]];

		// create tag
		[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Create Tag…", @"Contextual Menu Item to create a tag at the selected ref") action:@selector(createTag:) enabled:YES]];

		// view tag info
		if (ref.isTag) {
			[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"View Tag Info…", @"Contextual Menu Item to view Information about the selected tag") action:@selector(showTagInfoSheet:) enabled:YES]];
		}

		// Diff
		NSString *diffTitle = [NSString stringWithFormat:NSLocalizedString(@"Diff with “%@”", @"Contextual Menu Item to view a diff between the selected ref and HEAD"), headRefName];
		[items addObject:[PBRefMenuItem itemWithTitle:diffTitle action:@selector(diffWithHEAD:) enabled:!isHead]];
		[items addObject:[PBRefMenuItem separatorItem]];

		// merge ref
		NSString *mergeTitle = isOnHeadBranch
			? NSLocalizedString(@"Merge", @"Inactive Contextual Menu Item for merging")
			: [NSString stringWithFormat:@"Merge %@ into %@", refName, headRefName];
		[items addObject:[PBRefMenuItem itemWithTitle:mergeTitle action:@selector(merge:) enabled:!isOnHeadBranch]];

		// rebase
		NSString *rebaseTitle = isOnHeadBranch
			? NSLocalizedString(@"Rebase", @"Inactive Contextual Menu Item for rebasing")
			: [NSString stringWithFormat:NSLocalizedString(@"Rebase ”%@“ onto “%@”", @"Contextual Menu Item to rebase HEAD onto the selected ref"), headRefName, refName];
		[items addObject:[PBRefMenuItem itemWithTitle:rebaseTitle action:@selector(rebaseHeadBranch:) enabled:!isOnHeadBranch]];

		[items addObject:[PBRefMenuItem separatorItem]];
	}

	// fetch
	NSString *fetchTitle = hasRemote
		? [NSString stringWithFormat:NSLocalizedString(@"Fetch “%@”", @"Contextual Menu Item to fetch the selected remote"), remoteName]
		: NSLocalizedString(@"Fetch", @"Inactive Contextual Menu Item for fetching");
	[items addObject:[PBRefMenuItem itemWithTitle:fetchTitle action:@selector(fetchRemote:) enabled:hasRemote]];

	// pull
	NSString *pullTitle = hasRemote
		? [NSString stringWithFormat:NSLocalizedString(@"Pull “%@” and Update “%@”", @"Contextual Menu Item to pull the remote and update the selected branch"), remoteName, headRefName]
		: NSLocalizedString(@"Pull", @"Inactive Contextual Menu Item for pulling");
	[items addObject:[PBRefMenuItem itemWithTitle:pullTitle action:@selector(pullRemote:) enabled:hasRemote]];

	// push
	if (isRemote || ref.isRemoteBranch) {
		// push updates to remote
		NSString *pushTitle = [NSString stringWithFormat:NSLocalizedString(@"Push Updates to “%@”", @"Contextual Menu Item to push updates of the selected ref to he named remote"), remoteName];
		[items addObject:[PBRefMenuItem itemWithTitle:pushTitle action:@selector(pushUpdatesToRemote:) enabled:YES]];
	}
	else if (isDetachedHead) {
		[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Push", @"Inactive Contextual Menu Item for pushing") action:nil enabled:NO]];
	}
	else {
		// push to default remote
		BOOL hasDefaultRemote = NO;
		if (!ref.isTag && hasRemote) {
			hasDefaultRemote = YES;
			NSString *pushTitle = [NSString stringWithFormat:NSLocalizedString(@"Push “%@” to “%@”", @"Contextual Menu Item to push a ref to a specific remote"), refName, remoteName];
			[items addObject:[PBRefMenuItem itemWithTitle:pushTitle action:@selector(pushDefaultRemoteForRef:) enabled:YES]];
		}

		// push to remotes submenu
		NSArray *remoteNames = [repo remotes];
		if ([remoteNames count] && !(hasDefaultRemote && ([remoteNames count] == 1))) {
			NSString *pushToTitle = [NSString stringWithFormat:NSLocalizedString(@"Push “%@” to", @"Contextual Menu Submenu Item containing the remotes the selected ref can be pushed to"), refName];
			PBRefMenuItem *pushToItem = [PBRefMenuItem itemWithTitle:pushToTitle action:nil enabled:YES];
			NSMenu *remotesMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Remotes Menu", @"Menu listing the repository’s remotes")];
			for (NSString *remote in remoteNames) {
				PBRefMenuItem *remoteItem = [PBRefMenuItem itemWithTitle:remote action:@selector(pushToRemote:) enabled:YES];
				remoteItem.target = target;
				remoteItem.refishs = @[ref];
				remoteItem.representedObject = remote;
				[remotesMenu addItem:remoteItem];
			}
			[pushToItem setSubmenu:remotesMenu];
			[items addObject:pushToItem];
		}
	}

	// delete ref
	[items addObject:[PBRefMenuItem separatorItem]];
	BOOL isStash = [[ref ref] hasPrefix:@"refs/stash"];
	BOOL isDeleteEnabled = !(isDetachedHead || isHead || isStash);
	if (isDeleteEnabled) {
		NSString *deleteFormat = ref.isRemote
			? NSLocalizedString(@"Delete “%@”…", @"Contextual Menu Item to delete a local ref (e.g. branch)")
			: NSLocalizedString(@"Remove “%@”…", @"Contextual Menu Item to remove a remote");
		NSString *deleteItemTitle = [NSString stringWithFormat:deleteFormat, refName];
		PBRefMenuItem *deleteItem = [PBRefMenuItem itemWithTitle:deleteItemTitle action:@selector(showDeleteRefSheet:) enabled:YES];
		[items addObject:deleteItem];
	}

	for (PBRefMenuItem *item in items) {
		item.target = target;
		item.refishs = @[ref];
	}

	return items;
}


+ (NSArray<NSMenuItem *> *) defaultMenuItemsForCommits:(NSArray<PBGitCommit *> *)commits target:(id)target
{
	NSMutableArray *items = [NSMutableArray array];
	
	BOOL isSingleCommitSelection = commits.count == 1;
	PBGitCommit *firstCommit = commits.firstObject;
	
	NSString *headBranchName = firstCommit.repository.headRef.ref.shortName;
	BOOL isOnHeadBranch = firstCommit.isOnHeadBranch;
	BOOL isHead = [firstCommit.OID isEqual:firstCommit.repository.headOID];

	if (isSingleCommitSelection) {
		[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Checkout Commit", @"Contextual Menu Item to check out the selected commit") action:@selector(checkout:) enabled:YES]];
		[items addObject:[PBRefMenuItem separatorItem]];

		[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Create Branch…", @"Contextual Menu Item to create a branch at the selected commit") action:@selector(createBranch:) enabled:YES]];
		[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Create Tag…", @"Contextual Menu Item to create a tag at the selected commit") action:@selector(createTag:) enabled:YES]];
		[items addObject:[PBRefMenuItem separatorItem]];
	}
	
	[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Copy SHA", @"Contextual Menu Item to copy the selected commits’ full SHA(s)") action:@selector(copySHA:) enabled:YES]];
	[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Copy short SHA", @"Contextual Menu Item to copy the selected commits’ short SHA(s)") action:@selector(copyShortSHA:) enabled:YES]];
	[items addObject:[PBRefMenuItem itemWithTitle:NSLocalizedString(@"Copy Patch", @"Contextual Menu Item to copy the selected commits as patch(es)") action:@selector(copyPatch:) enabled:YES]];

	if (isSingleCommitSelection) {
		NSString *diffTitle = [NSString stringWithFormat:NSLocalizedString(@"Diff with “%@”", @"Contextual Menu Item to view a diff between the selected commit and HEAD"), headBranchName];
		[items addObject:[PBRefMenuItem itemWithTitle:diffTitle action:@selector(diffWithHEAD:) enabled:!isHead]];
		[items addObject:[PBRefMenuItem separatorItem]];

		// merge commit
		NSString *mergeTitle = isOnHeadBranch
			? NSLocalizedString(@"Merge Commit", @"Inactive Contextual Menu Item for merging commits")
			: [NSString stringWithFormat:NSLocalizedString(@"Merge Commit into “%@”", @"Contextual Menu Item to merge the selected commit into HEAD"), headBranchName];
		[items addObject:[PBRefMenuItem itemWithTitle:mergeTitle action:@selector(merge:) enabled:!isOnHeadBranch]];

		// cherry pick
		NSString *cherryPickTitle = isOnHeadBranch
			? NSLocalizedString(@"Cherry Pick Commit", @"Inactive Contextual Menu Item for cherry-picking commits")
			: [NSString stringWithFormat:NSLocalizedString(@"Cherry Pick Commit to “%@”", @"Contextual Menu Item to cherry-pick the selected commit on top of HEAD"), headBranchName];
		[items addObject:[PBRefMenuItem itemWithTitle:cherryPickTitle action:@selector(cherryPick:) enabled:!isOnHeadBranch]];

		// rebase
		NSString *rebaseTitle = isOnHeadBranch
			? NSLocalizedString(@"Rebase Commit", @"Inactive Contextual Menu Item for rebasing onto commits")
			: [NSString stringWithFormat:NSLocalizedString(@"Rebase “%@” onto Commit", @"Contextual Menu Item to rebase the HEAD branch onto the selected commit"), headBranchName];
		[items addObject:[PBRefMenuItem itemWithTitle:rebaseTitle action:@selector(rebaseHeadBranch:) enabled:!isOnHeadBranch]];
	}
	
	for (PBRefMenuItem *item in items) {
		item.target = target;
		item.refishs = commits;
	}

	return items;
}


@end
