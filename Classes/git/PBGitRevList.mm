//
//  PBGitRevList.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevList.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitGrapher.h"
#import "PBGitRevSpecifier.h"
#import "PBEasyPipe.h"
#import "PBGitBinary.h"

#import <ObjectiveGit/ObjectiveGit.h>

#import <ext/stdio_filebuf.h>
#import <iostream>
#import <string>
#import <map>
#import <ObjectiveGit/GTOID.h>

using namespace std;


@interface PBGitRevList ()

@property (nonatomic, assign) BOOL isGraphing;
@property (nonatomic, assign) BOOL resetCommits;

@property (nonatomic, weak) PBGitRepository *repository;
@property (nonatomic, strong) PBGitRevSpecifier *currentRev;

@property (nonatomic, strong) NSMutableDictionary *commitCache;

@property (nonatomic, strong) NSThread *parseThread;

@end


#define kRevListRevisionsKey @"revisions"


@implementation PBGitRevList

- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph
{
	self = [super init];
	if (!self) {
		return nil;
	}
	self.repository = repo;
	self.currentRev = [rev copy];
	self.isGraphing = graph;
	self.commitCache = [NSMutableDictionary new];
	
	return self;
}


- (void) loadRevisons
{
	[self cancel];
	
	self.parseThread = [[NSThread alloc] initWithTarget:self selector:@selector(beginWalkWithSpecifier:) object:self.currentRev];
	self.isParsing = YES;
	self.resetCommits = YES;
	[self.parseThread start];
}


- (void)cancel
{
	[self.parseThread cancel];
	self.parseThread = nil;
	self.isParsing = NO;
}


- (void) finishedParsing
{
	self.parseThread = nil;
	self.isParsing = NO;
}


- (void) updateCommits:(NSDictionary *)update
{
	NSArray *revisions = [update objectForKey:kRevListRevisionsKey];
	if (!revisions || [revisions count] == 0)
		return;
	
	if (self.resetCommits) {
		self.commits = [NSMutableArray array];
		self.resetCommits = NO;
	}
	
	NSRange range = NSMakeRange([self.commits count], [revisions count]);
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:range];
	
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
	[self.commits addObjectsFromArray:revisions];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
}

- (void) beginWalkWithSpecifier:(PBGitRevSpecifier*)rev
{
	PBGitRepository *pbRepo = self.repository;
	GTRepository *repo = pbRepo.gtRepo;
	
	NSError *error = nil;
	GTEnumerator *enu = [[GTEnumerator alloc] initWithRepository:repo error:&error];
	
	[self setupEnumerator:enu forRevspec:rev];
	
	[self addCommitsFromEnumerator:enu inPBRepo:pbRepo];
}

- (void) addGitObject:(GTObject *)obj toCommitSet:(NSMutableSet *)set
{
	GTCommit *commit = nil;
	if ([obj isKindOfClass:[GTCommit class]]) {
		commit = (GTCommit *)obj;
	} else {
		NSError *peelError = nil;
		commit = [obj objectByPeelingToType:GTObjectTypeCommit error:&peelError];
	}

	NSAssert(commit, @"Can't add nil commit to set");

	for (GTCommit *item in set) {
		if ([item.OID isEqual:commit.OID]) {
			return;
		}
	}

	[set addObject:commit];
}

- (void) addGitBranches:(NSArray *)branches fromRepo:(GTRepository *)repo toCommitSet:(NSMutableSet *)set
{
	for (GTBranch *branch in branches) {
		NSError *objectLookupError = nil;
		GTObject *gtObject = [repo lookUpObjectBySHA:branch.SHA error:&objectLookupError];
		[self addGitObject:gtObject toCommitSet:set];
	}
}

- (void) setupEnumerator:(GTEnumerator*)enumerator
			  forRevspec:(PBGitRevSpecifier*)rev
{
	NSError *error = nil;
	GTRepository *repo = enumerator.repository;
	// [enumerator resetWithOptions:GTEnumeratorOptionsTimeSort];
	[enumerator resetWithOptions:GTEnumeratorOptionsTopologicalSort];
	NSMutableSet *enumCommits = [NSMutableSet new];
	if (rev.isSimpleRef) {
		GTObject *object = [repo lookUpObjectByRevParse:rev.simpleRef error:&error];
		[self addGitObject:object toCommitSet:enumCommits];
	} else {
		NSArray *allRefs = [repo referenceNamesWithError:&error];
		for (NSString *param in rev.parameters) {
			if ([param isEqualToString:@"--branches"]) {
				NSArray *branches = [repo localBranchesWithError:&error];
				[self addGitBranches:branches fromRepo:repo toCommitSet:enumCommits];
			} else if ([param isEqualToString:@"--remotes"]) {
				NSArray *branches = [repo remoteBranchesWithError:&error];
				[self addGitBranches:branches fromRepo:repo toCommitSet:enumCommits];
			} else if ([param isEqualToString:@"--tags"]) {
				for (NSString *ref in allRefs) {
					if ([ref hasPrefix:@"refs/tags/"]) {
						GTObject *tag = [repo lookUpObjectByRevParse:ref error:&error];
						GTCommit *commit = nil;
						if ([tag isKindOfClass:[GTCommit class]]) {
							commit = (GTCommit *)tag;
						} else if ([tag isKindOfClass:[GTTag class]]) {
							NSError *tagError = nil;
							commit = [(GTTag *)tag objectByPeelingTagError:&tagError];
						}

						if ([commit isKindOfClass:[GTCommit class]])
						{
							[self addGitObject:commit toCommitSet:enumCommits];
						}
					}
				}
			} else if ([param hasPrefix:@"--glob="]) {
				[enumerator pushGlob:[param substringFromIndex:@"--glob=".length] error:&error];
			} else {
				NSError *lookupError = nil;
				GTObject *obj = [repo lookUpObjectByRevParse:param error:&lookupError];
				if (obj && !lookupError) {
					[self addGitObject:obj toCommitSet:enumCommits];
				} else {
					[enumerator pushGlob:param error:&error];
				}
			}
		}
	}

	NSArray *sortedBranchesAndTags = [[enumCommits allObjects] sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(id obj1, id obj2) {
		GTCommit *branchCommit1 = obj1;
		GTCommit *branchCommit2 = obj2;

		return [branchCommit2.commitDate compare:branchCommit1.commitDate];
	}];

	for (GTCommit *commit in sortedBranchesAndTags) {
		NSError *pushError = nil;
		[enumerator pushSHA:commit.SHA error:&pushError];
	}


}

- (void) addCommitsFromEnumerator:(GTEnumerator *)enumerator
						 inPBRepo:(PBGitRepository*)pbRepo;
{
	PBGitGrapher *g = [[PBGitGrapher alloc] initWithRepository:pbRepo];
	__block NSDate *lastUpdate = [NSDate date];

	dispatch_queue_t loadQueue = dispatch_queue_create("net.phere.gitx.loadQueue", 0);
	dispatch_queue_t decorateQueue = dispatch_queue_create("net.phere.gitx.decorateQueue", 0);
	dispatch_group_t loadGroup = dispatch_group_create();
	dispatch_group_t decorateGroup = dispatch_group_create();
	
	BOOL enumSuccess = FALSE;
	GTCommit *commit = nil;
	__block int num = 0;
	__block NSMutableArray *revisions = [NSMutableArray array];
	NSError *enumError = nil;
	while ((commit = [enumerator nextObjectWithSuccess:&enumSuccess error:&enumError]) && enumSuccess) {
		//GTOID *oid = [[GTOID alloc] initWithSHA:commit.sha];
		
		dispatch_group_async(loadGroup, loadQueue, ^{
			PBGitCommit *newCommit = nil;
			PBGitCommit *cachedCommit = [self.commitCache objectForKey:commit.SHA];
			if (cachedCommit) {
				newCommit = cachedCommit;
			} else {
				newCommit = [[PBGitCommit alloc] initWithRepository:pbRepo andCommit:commit];
				[self.commitCache setObject:newCommit forKey:commit.SHA];
			}
			
			[revisions addObject:newCommit];
			
			if (self.isGraphing) {
				dispatch_group_async(decorateGroup, decorateQueue, ^{
					[g decorateCommit:newCommit];
				});
			}
			
			if (++num % 100 == 0) {
				if ([[NSDate date] timeIntervalSinceDate:lastUpdate] > 0.5 && ![[NSThread currentThread] isCancelled]) {
					dispatch_group_wait(decorateGroup, DISPATCH_TIME_FOREVER);
					NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:revisions, kRevListRevisionsKey, nil];
					[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:NO];
					revisions = [NSMutableArray array];
					lastUpdate = [NSDate date];
				}
			}
		});
	}

	NSAssert(!enumError, @"Error enumerating commits");
	
	dispatch_group_wait(loadGroup, DISPATCH_TIME_FOREVER);
	dispatch_group_wait(decorateGroup, DISPATCH_TIME_FOREVER);
	
	// Make sure the commits are stored before exiting.
	if (![[NSThread currentThread] isCancelled]) {
		NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:revisions, kRevListRevisionsKey, nil];
		[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:YES];
		
		[self performSelectorOnMainThread:@selector(finishedParsing) withObject:nil waitUntilDone:NO];
	}
}

@end
