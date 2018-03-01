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
#import "PBGitBinary.h"

#import <ObjectiveGit/ObjectiveGit.h>
#import "ObjectiveGit+PBCategories.h"

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

@property (nonatomic, strong) NSCache<GTOID *, PBGitCommit *> *commitCache;

@property (nonatomic, strong) NSOperationQueue *operationQueue;

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
	self.commitCache = [[NSCache alloc] init];
	self.operationQueue = [[NSOperationQueue alloc] init];
	self.operationQueue.maxConcurrentOperationCount = 1;
	self.operationQueue.qualityOfService = NSQualityOfServiceUtility;
	
	return self;
}

- (void)loadRevisonsWithCompletionBlock:(void(^)(void))completionBlock
{
	[self cancel];

	self.resetCommits = YES;

	NSBlockOperation *parseOperation = [[NSBlockOperation alloc] init];

	__weak typeof(self) weakSelf = self;
	__weak typeof(parseOperation) weakParseOperation = parseOperation;

	[parseOperation addExecutionBlock:^{
		PBGitRepository *pbRepo = weakSelf.repository;
		GTRepository *repo = pbRepo.gtRepo;

		NSError *error = nil;
		GTEnumerator *enu = [[GTEnumerator alloc] initWithRepository:repo error:&error];

		[weakSelf setupEnumerator:enu forRevspec:weakSelf.currentRev];
		[weakSelf addCommitsFromEnumerator:enu inPBRepo:pbRepo operation:weakParseOperation];
	}];
	[parseOperation setCompletionBlock:completionBlock];

	[self.operationQueue addOperation:parseOperation];
}


- (void)cancel
{
	[self.operationQueue cancelAllOperations];
}

- (BOOL)isParsing
{
	return self.operationQueue.operationCount > 0;
}


- (void) updateCommits:(NSArray<PBGitCommit *> *)revisions operation:(NSOperation *)operation
{
	if (!revisions || [revisions count] == 0 || operation.cancelled)
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

static BOOL hasParameter(NSMutableArray *parameters, NSString *paramName) {
	NSUInteger index = NSNotFound;

	index = [parameters indexOfObject:paramName];
	if (index == NSNotFound) return NO;

	[parameters removeObjectAtIndex:index];
	return YES;
}

- (void) setupEnumerator:(GTEnumerator*)enumerator
			  forRevspec:(PBGitRevSpecifier *)rev
{
	NSError *error = nil;
	BOOL success = NO;
	GTRepository *repo = enumerator.repository;
	[enumerator resetWithOptions:GTEnumeratorOptionsTopologicalSort|GTEnumeratorOptionsTimeSort];

	if (rev.isSimpleRef) {
		GTObject *object = [repo lookUpObjectByRevParse:rev.simpleRef error:&error];
		if (object) {
			success = [enumerator pushSHA:object.SHA error:&error];
		}
		if (!object || (object && !success)) {
			NSLog(@"Failed to push simple ref %@: %@", rev.simpleRef, error);
		}
		return;
	}

	NSMutableArray *parameters = [rev.parameters mutableCopy];
	BOOL addBranches = hasParameter(parameters, @"--branches");
	BOOL addRemotes = hasParameter(parameters, @"--remotes");
	BOOL addTags = hasParameter(parameters, @"--tags");

	NSArray *allRefs = [repo referenceNamesWithError:&error];

	// First, loop over all the known references, and add the ones we want
	if (addBranches || addRemotes || addTags) {
		for (NSString *referenceName in allRefs) {
			if ((addBranches && [referenceName hasPrefix:[GTBranch localNamePrefix]])
				|| (addRemotes && [referenceName hasPrefix:[GTBranch remoteNamePrefix]])
				|| (addTags && [referenceName hasPrefix:@"refs/tags/"])) {
				success = [enumerator pushReferenceName:referenceName error:&error];
				if (!success) {
					NSLog(@"Failed to push reference %@: %@", referenceName, error);
				}
			}
		}
	}

	// Handle the rest of our (less obvious) parameters
	for (NSString *param in parameters) {
		if ([param hasPrefix:@"--glob="]) {
			success = [enumerator pushGlob:[param substringFromIndex:@"--glob=".length] error:&error];
			if (!success) {
				NSLog(@"Failed to push glob %@: %@", param, error);
			}
		} else {
			NSError *lookupError = nil;
			GTObject *obj = [repo lookUpObjectByRevParse:param error:&lookupError];
			if (obj) {
				success = [enumerator pushSHA:obj.SHA error:&error];
			} else {
				success = [enumerator pushGlob:param error:&error];
			}
			if (!success) {
				NSLog(@"Failed to push remaining parameter %@: %@", param, error);
			}
		}
	}

}

- (void) addCommitsFromEnumerator:(GTEnumerator *)enumerator inPBRepo:(PBGitRepository*)pbRepo operation:(NSOperation *)operation
{
	PBGitGrapher *g = [[PBGitGrapher alloc] initWithRepository:pbRepo];
	__block NSDate *lastUpdate = [NSDate date];

	dispatch_queue_t loadQueue = dispatch_queue_create("net.phere.gitx.loadQueue", 0);
	dispatch_queue_t decorateQueue = dispatch_queue_create("net.phere.gitx.decorateQueue", 0);
	dispatch_group_t loadGroup = dispatch_group_create();
	dispatch_group_t decorateGroup = dispatch_group_create();
	
	BOOL enumSuccess = FALSE;
	__block int num = 0;
	__block NSMutableArray<PBGitCommit *> *revisions = [NSMutableArray array];
	NSError *enumError = nil;
	GTOID *oid = nil;
	while ((oid = [enumerator nextOIDWithSuccess:&enumSuccess error:&enumError]) && enumSuccess && !operation.cancelled) {
		dispatch_group_async(loadGroup, loadQueue, ^{
			if (operation.cancelled) {
				return;
			}

			PBGitCommit *newCommit = nil;
			PBGitCommit *cachedCommit = [self.commitCache objectForKey:oid];
			if (cachedCommit) {
				newCommit = cachedCommit;
			} else {
				GTCommit *commit = (GTCommit *)[pbRepo.gtRepo lookUpObjectByOID:oid error:NULL];
				if (!commit) {
					[NSException raise:NSInternalInconsistencyException format:@"Missing commit with OID %@", oid];
				}

				newCommit = [[PBGitCommit alloc] initWithRepository:pbRepo andCommit:commit];
				[self.commitCache setObject:newCommit forKey:oid];
			}
			
			[revisions addObject:newCommit];
			
			if (self.isGraphing) {
				dispatch_group_async(decorateGroup, decorateQueue, ^{
					[g decorateCommit:newCommit];
				});
			}
			
			if (++num % 100 == 0 && [[NSDate date] timeIntervalSinceDate:lastUpdate] > 0.2) {
				dispatch_group_wait(decorateGroup, DISPATCH_TIME_FOREVER);

				NSArray<PBGitCommit *> *updatedRevisions = [revisions copy];

				dispatch_async(dispatch_get_main_queue(), ^{
					[self updateCommits:updatedRevisions operation:operation];
				});

				[revisions removeAllObjects];
				lastUpdate = [NSDate date];
			}
		});
	}

	NSAssert(!enumError, @"Error enumerating commits");
	
	dispatch_group_wait(loadGroup, DISPATCH_TIME_FOREVER);
	dispatch_group_wait(decorateGroup, DISPATCH_TIME_FOREVER);
	
	// Make sure the commits are stored before exiting.
	NSArray<PBGitCommit *> *updatedRevisions = [revisions copy];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self updateCommits:updatedRevisions operation:operation];
	});
}

@end
