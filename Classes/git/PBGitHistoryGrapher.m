//
//  PBGitHistoryGrapher.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitHistoryGrapher.h"
#import "PBGitGrapher.h"
#import "PBGitCommit.h"

@implementation PBGitHistoryGrapher


- (id) initWithBaseCommits:(NSSet *)commits viewAllBranches:(BOOL)viewAll queue:(NSOperationQueue *)queue delegate:(id)theDelegate
{
    self = [super init];

	delegate = theDelegate;
	currentQueue = queue;
	searchOIDs = [NSMutableSet setWithSet:commits];
	grapher = [[PBGitGrapher alloc] initWithRepository:nil];
	viewAllBranches = viewAll;

	return self;
}


- (void)sendCommits:(NSArray *)commits
{
	NSDictionary *commitData = [NSDictionary dictionaryWithObjectsAndKeys:currentQueue, kCurrentQueueKey, commits, kNewCommitsKey, nil];
	id strongDelegate = delegate;
	[strongDelegate performSelectorOnMainThread:@selector(updateCommitsFromGrapher:) withObject:commitData waitUntilDone:NO];
}


- (void) graphCommits:(NSArray *)revList
{
	if (!revList || [revList count] == 0)
		return;

	id strongDelegate = delegate;
	//NSDate *start = [NSDate date];
	NSThread *currentThread = [NSThread currentThread];
	NSDate *lastUpdate = [NSDate date];
	NSMutableArray *commits = [NSMutableArray array];
	NSInteger counter = 0;

	for (PBGitCommit *commit in revList) {
		if ([currentThread isCancelled])
			return;
		GTOID *commitOID = commit.OID;
		if (viewAllBranches || [searchOIDs containsObject:commitOID]) {
			[grapher decorateCommit:commit];
			[commits addObject:commit];
			if (!viewAllBranches) {
				[searchOIDs removeObject:commitOID];
				[searchOIDs addObjectsFromArray:[commit parents]];
			}
		}
		if (++counter % 100 == 0) {
			if ([[NSDate date] timeIntervalSinceDate:lastUpdate] > 0.5) {
				[self sendCommits:commits];
				commits = [NSMutableArray array];
				lastUpdate = [NSDate date];
			}
		}
	}
	//NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
	//NSLog(@"Graphed %i commits in %f seconds (%f/sec)", counter, duration, counter/duration);

	[self sendCommits:commits];
	[strongDelegate performSelectorOnMainThread:@selector(finishedGraphing) withObject:nil waitUntilDone:NO];
}


@end
