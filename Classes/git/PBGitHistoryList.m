//
//  PBGitHistoryList.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitHistoryList.h"
#import "PBGitRepository.h"
#import "PBGitRevList.h"
#import "PBGitGrapher.h"
#import "PBGitHistoryGrapher.h"
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"

@interface PBGitHistoryList ()

- (void) resetGraphing;

- (PBGitHistoryGrapher *) grapher;
- (NSInvocationOperation *) operationForCommits:(NSArray *)newCommits;

- (void) updateProjectHistoryForRev:(PBGitRevSpecifier *)rev;
- (void) updateHistoryForRev:(PBGitRevSpecifier *)rev;

@end




@implementation PBGitHistoryList


@synthesize projectRevList;
@synthesize commits;
@synthesize isUpdating;
@dynamic projectCommits;



#pragma mark -
#pragma mark Public

- (id) initWithRepository:(PBGitRepository *)repo
{
    self = [super init];
    if (!self)
        return nil;
    
	commits = [NSMutableArray array];
	repository = repo;
	lastBranchFilter = -1;

	shouldReloadProjectHistory = YES;
	projectRevList = [[PBGitRevList alloc] initWithRepository:repository rev:[PBGitRevSpecifier allBranchesRevSpec] shouldGraph:NO];

	return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void) forceUpdate
{
	if ([repository.currentBranch isSimpleRef])
		shouldReloadProjectHistory = YES;

	[self updateHistory];
}


- (void) updateHistory
{
	PBGitRevSpecifier *rev = repository.currentBranch;
	if (!rev)
		return;

	if ([rev isSimpleRef])
		[self updateProjectHistoryForRev:rev];
	else
		[self updateHistoryForRev:rev];
}


- (void)cleanup
{
	if (currentRevList) {
		[currentRevList removeObserver:self forKeyPath:@"commits"];
		[currentRevList cancel];
		currentRevList = nil;
	}
	[graphQueue cancelAllOperations];

}


- (NSArray *) projectCommits
{
	return [projectRevList.commits copy];
}



#pragma mark -
#pragma mark History Grapher delegate methods

- (void) addCommitsFromArray:(NSArray *)array
{
	if (!array || [array count] == 0)
		return;

	if (resetCommits) {
		self.commits = [NSMutableArray array];
		resetCommits = NO;
	}

	NSRange range = NSMakeRange([commits count], [array count]);
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:range];

	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
	[commits addObjectsFromArray:array];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
}


- (void) updateCommitsFromGrapher:(NSDictionary *)commitData
{
	if ([commitData objectForKey:kCurrentQueueKey] != graphQueue)
		return;

	[self addCommitsFromArray:[commitData objectForKey:kNewCommitsKey]];
}

- (void) finishedGraphing
{
	if (!currentRevList.parsing && ([[graphQueue operations] count] == 0)) {
		self.isUpdating = NO;
	}
}



#pragma mark -
#pragma mark Private

- (void) resetGraphing
{
	resetCommits = YES;
	self.isUpdating = YES;

	[graphQueue cancelAllOperations];
	graphQueue = [[NSOperationQueue alloc] init];
	[graphQueue setMaxConcurrentOperationCount:1];

	grapher = [self grapher];
}


- (NSInvocationOperation *) operationForCommits:(NSArray *)newCommits
{
	return [[NSInvocationOperation alloc] initWithTarget:grapher selector:@selector(graphCommits:) object:newCommits];
}


- (NSSet *) baseCommitsForLocalRefs
{
	NSMutableSet *baseCommitOIDs = [NSMutableSet set];
	NSDictionary *refs = repository.refs;

	for (GTOID *OID in refs)
		for (PBGitRef *ref in [refs objectForKey:OID])
			if ([ref isBranch] || [ref isTag])
				[baseCommitOIDs addObject:OID];

	if (![[PBGitRef refFromString:[[repository headRef] simpleRef]] type])
		[baseCommitOIDs addObject:repository.headOID];

	return baseCommitOIDs;
}


- (NSSet *) baseCommitsForRemoteRefs
{
	NSMutableSet *baseCommitOIDs = [NSMutableSet set];
	NSDictionary *refs = repository.refs;

	PBGitRef *remoteRef = [[repository.currentBranch ref] remoteRef];

	for (GTOID *OID in refs)
		for (PBGitRef *ref in [refs objectForKey:OID])
			if ([remoteRef isEqualToRef:[ref remoteRef]])
				[baseCommitOIDs addObject:OID];

	return baseCommitOIDs;
}


- (NSSet *) baseCommits
{
	if ((repository.currentBranchFilter == kGitXSelectedBranchFilter) || (repository.currentBranchFilter == kGitXAllBranchesFilter)) {
		if (lastOID)
			return [NSMutableSet setWithObject:lastOID];
		else if ([repository.currentBranch isSimpleRef]) {
			PBGitRef *currentRef = [repository.currentBranch ref];
			GTOID *OID = [repository OIDForRef:currentRef];
			if (OID)
				return [NSMutableSet setWithObject:OID];
		}
	}
	else if (repository.currentBranchFilter == kGitXLocalRemoteBranchesFilter) {
		if ([[repository.currentBranch ref] isRemote])
			return [self baseCommitsForRemoteRefs];
		else
			return [self baseCommitsForLocalRefs];
	}

	return [NSMutableSet set];
}


- (PBGitHistoryGrapher *) grapher
{
	BOOL viewAllBranches = (repository.currentBranchFilter == kGitXAllBranchesFilter);

	return [[PBGitHistoryGrapher alloc] initWithBaseCommits:[self baseCommits] viewAllBranches:viewAllBranches queue:graphQueue delegate:self];
}


- (void) setCurrentRevList:(PBGitRevList *)parser
{
	if (currentRevList == parser)
		return;

	if (currentRevList)
		[currentRevList removeObserver:self forKeyPath:@"commits"];

	currentRevList = parser;

	[currentRevList addObserver:self forKeyPath:@"commits" options:NSKeyValueObservingOptionNew context:@"commitsUpdated"];
}


- (BOOL) isAllBranchesOnlyUpdate
{
	return (lastBranchFilter == kGitXAllBranchesFilter) && (repository.currentBranchFilter == kGitXAllBranchesFilter);
}


- (BOOL) isLocalRemoteOnlyUpdate:(PBGitRevSpecifier *)rev
{
	if ((lastBranchFilter == kGitXLocalRemoteBranchesFilter) && (repository.currentBranchFilter == kGitXLocalRemoteBranchesFilter)) {
		if (!lastRemoteRef && ![[rev ref] isRemote])
			return YES;

		if ([lastRemoteRef isEqualToRef:[[rev ref] remoteRef]])
			return YES;
	}

	return NO;
}


- (BOOL) selectedBranchNeedsNewGraph:(PBGitRevSpecifier *)rev
{
	if (![rev isSimpleRef])
		return YES;

	if ([self isAllBranchesOnlyUpdate] || [self isLocalRemoteOnlyUpdate:rev]) {
		lastRemoteRef = [[rev ref] remoteRef];
		lastOID = nil;
		self.isUpdating = NO;
		return NO;
	}

	GTOID *revOID = [repository OIDForRef:[rev ref]];
	if ([revOID isEqual:lastOID] && (lastBranchFilter == repository.currentBranchFilter))
		return NO;

	lastBranchFilter = repository.currentBranchFilter;
	lastRemoteRef = [[rev ref] remoteRef];
	lastOID = revOID;

	return YES;
}


- (BOOL) haveRefsBeenModified
{
	[repository reloadRefs];

	NSMutableSet *currentRefOIDs = [NSMutableSet setWithArray:[repository.refs allKeys]];
	[currentRefOIDs minusSet:lastRefOIDs];
	lastRefOIDs = [NSSet setWithArray:[repository.refs allKeys]];

	return [currentRefOIDs count] != 0;
}


#pragma mark updating history

- (void) updateProjectHistoryForRev:(PBGitRevSpecifier *)rev
{
	[self setCurrentRevList:projectRevList];

	if ([self haveRefsBeenModified])
		shouldReloadProjectHistory = YES;

	if (![self selectedBranchNeedsNewGraph:rev] && !shouldReloadProjectHistory)
		return;

	[self resetGraphing];

	if (shouldReloadProjectHistory) {
		shouldReloadProjectHistory = NO;
		lastBranchFilter = -1;
		lastRemoteRef = nil;
		lastOID = nil;
		self.commits = [NSMutableArray array];
		[projectRevList loadRevisonsWithCompletionBlock:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self finishedGraphing];
			});
		}];
	} else {
		[graphQueue addOperation:[self operationForCommits:projectRevList.commits]];
	}
}


- (void) updateHistoryForRev:(PBGitRevSpecifier *)rev
{
	PBGitRevList *otherRevListParser = [[PBGitRevList alloc] initWithRepository:repository rev:rev shouldGraph:YES];

	[self setCurrentRevList:otherRevListParser];
	[self resetGraphing];
	lastBranchFilter = -1;
	lastRemoteRef = nil;
	lastOID = nil;
	self.commits = [NSMutableArray array];

	[otherRevListParser loadRevisonsWithCompletionBlock:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self finishedGraphing];
		});
	}];
}



#pragma mark -
#pragma mark Key Value Observing
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([@"commitsUpdated" isEqualToString:(__bridge NSString*)context]) {
		NSInteger changeKind = [(NSNumber *)[change objectForKey:NSKeyValueChangeKindKey] intValue];
		if (changeKind == NSKeyValueChangeInsertion) {
			NSArray *newCommits = [change objectForKey:NSKeyValueChangeNewKey];
			if ([repository.currentBranch isSimpleRef])
				[graphQueue addOperation:[self operationForCommits:newCommits]];
			else
				[self addCommitsFromArray:newCommits];
		}
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
