//
//  PBGitRepository.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"

#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitCommit.h"
#import "PBGitIndex.h"
#import "PBGitWindowController.h"
#import "PBGitRepositoryDocument.h"
#import "PBGitBinary.h"

#import "NSFileHandleExt.h"
#import "PBTask.h"
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"
#import "PBRemoteProgressSheet.h"
#import "PBGitRevList.h"
#import "PBGitDefaults.h"
#import "GitXScriptingConstants.h"
#import "PBHistorySearchController.h"
#import "PBGitRepositoryWatcher.h"
#import "PBRepositoryFinder.h"
#import "PBGitHistoryList.h"
#import "PBGitStash.h"
#import "PBError.h"

@interface PBGitRepository () {
	__strong PBGitRepositoryWatcher *watcher;
	__strong PBGitRevSpecifier *_headRef; // Caching
	__strong GTOID* _headOID;
	__strong GTRepository* _gtRepo;
	PBGitIndex *_index;
}

@property (nonatomic, strong) NSNumber *hasSVNRepoConfig;

@end

@implementation PBGitRepository

@synthesize revisionList, branchesSet, currentBranch, currentBranchFilter, hasChanged, refs;

#pragma mark -
#pragma mark Memory management

- (id)init
{
    self = [super init];
    if (!self) return nil;

	self.branchesSet = [NSMutableOrderedSet orderedSet];
    self.submodules = [NSMutableArray array];
	currentBranchFilter = [PBGitDefaults branchFilter];
    return self;
}

- (id)initWithURL:(NSURL *)repositoryURL error:(NSError **)error
{
	self = [self init];
	if (!self) return nil;

	NSError *gtError = nil;
	NSURL *repoURL = [PBRepositoryFinder gitDirForURL:repositoryURL];
	_gtRepo = [GTRepository repositoryWithURL:repoURL error:&gtError];
	if (!_gtRepo) {
		if (error) {
			*error = [NSError pb_errorWithDescription:NSLocalizedString(@"Repository initialization failed", @"")
										failureReason:[NSString stringWithFormat:NSLocalizedString(@"%@ does not appear to be a git repository.", @""), repositoryURL.path]
									  underlyingError:gtError];
		}
		return nil;
	}

	revisionList = [[PBGitHistoryList alloc] initWithRepository:self];

	[self reloadRefs];

    // Setup the FSEvents watcher to fire notifications when things change
    watcher = [[PBGitRepositoryWatcher alloc] initWithRepository:self];

	return self;
}

- (void) dealloc
{
	// NSLog(@"Dealloc of repository");
	[watcher stop];
}

#pragma mark -
#pragma mark Properties/General methods

- (NSURL *)getIndexURL
{
	NSError *error = nil;
	GTIndex *index = [self.gtRepo indexWithError:&error];
    if (index == nil) {
        NSLog(@"getIndexURL failed with error %@", error);
        return nil;
    }
	NSURL* result = index.fileURL;
	return result;
}

- (BOOL)isBareRepository
{
    return self.gtRepo.isBare;
}

- (BOOL)isShallowRepository
{
	// Using low-level function because GTRepository does not currently
    // expose this information itself.
	return (BOOL)git_repository_is_shallow(self.gtRepo.git_repository);
}

- (BOOL)readHasSVNRemoteFromConfig
{
	NSError *error = nil;
	GTConfiguration *config = [self.gtRepo configurationWithError:&error];
	NSArray *allKeys = config.configurationKeys;
	for (NSString *key in allKeys) {
		if ([key hasPrefix:@"svn-remote."]) {
			return TRUE;
		}
	}
	return false;
}

- (BOOL)hasSVNRemote
{
	if (!self.hasSVNRepoConfig) {
		self.hasSVNRepoConfig = @([self readHasSVNRemoteFromConfig]);
	}
	return [self.hasSVNRepoConfig boolValue];
}

- (NSURL *)gitURL {
    return self.gtRepo.gitDirectoryURL;
}

- (NSURL *)workingDirectoryURL {
    return self.gtRepo.fileURL;
}

- (NSString *)workingDirectory
{
    return self.workingDirectoryURL.path;
}

- (void)forceUpdateRevisions
{
	[revisionList forceUpdate];
}

- (NSString *)projectName
{
	NSString* result = [self.workingDirectory lastPathComponent];
	return result;
}

// Get the .gitignore file at the root of the repository
- (NSString *)gitIgnoreFilename
{
	return [[self workingDirectory] stringByAppendingPathComponent:@".gitignore"];
}

- (void)addRef:(GTReference *)gtRef
{
	GTObject *refTarget = gtRef.resolvedTarget;
	if (![refTarget isKindOfClass:[GTObject class]]) {
		NSLog(@"Tried to add invalid ref %@ -> %@", gtRef, refTarget);
		return;
	}

	GTOID *sha = refTarget.OID;
	if (!sha) {
		NSLog(@"Couldn't determine sha for ref %@ -> %@", gtRef, refTarget);
		return;
	}

	PBGitRef* ref = [[PBGitRef alloc] initWithString:gtRef.name];
//	NSLog(@"addRef %@ %@ at %@", ref.type, gtRef.name, [sha string]);
	NSMutableArray* curRefs = refs[sha];
	if ( curRefs != nil ) {
		if ([curRefs containsObject:ref]) {
			NSLog(@"Duplicate ref shouldn't be added: %@", ref);
			return;
		}
		[curRefs addObject:ref];
	} else {
		refs[sha] = [NSMutableArray arrayWithObject:ref];
	}
}

- (void)loadSubmodules
{
    self.submodules = [NSMutableArray array];

    [self.gtRepo enumerateSubmodulesRecursively:NO usingBlock:^(GTSubmodule *gtSubmodule, NSError *error, BOOL *stop) {
		[self.submodules addObject:gtSubmodule];
    }];
}

- (void) reloadRefs
{
	// clear out ref caches
	_headRef = nil;
	_headOID = nil;
	self->refs = [NSMutableDictionary dictionary];
	
	NSError* error = nil;
	NSArray* allRefs = [self.gtRepo referenceNamesWithError:&error];

	if ([self.gtRepo isHEADDetached]) {
		// Add HEAD when we're detached
		allRefs = [allRefs arrayByAddingObject:@"HEAD"];
	}
	
	// load all named refs
	NSMutableOrderedSet *oldBranches = [self.branchesSet mutableCopy];
	for (NSString* referenceName in allRefs)
	{
		GTReference* gtRef = [self.gtRepo lookUpReferenceWithName:referenceName error:&error];
		
		if (gtRef == nil)
		{
			NSLog(@"Reference \"%@\" could not be found in the repository", referenceName);
			if (error)
			{
				NSLog(@"Error loading reference was: %@", error);
			}
			continue;
		}
		if (gtRef.remote && gtRef.referenceType == GTReferenceTypeSymbolic) {
			// Hide remote symbolic references like origin/HEAD
			continue;
		}
		PBGitRef* gitRef = [PBGitRef refFromString:referenceName];
		PBGitRevSpecifier* revSpec = [[PBGitRevSpecifier alloc] initWithRef:gitRef];
		[self addBranch:revSpec];
		[self addRef:gtRef];
		[oldBranches removeObject:revSpec];
	}
	
	for (PBGitRevSpecifier *branch in oldBranches)
		if ([branch isSimpleRef] && ![branch isEqual:[self headRef]])
			[self removeBranch:branch];


    [self loadSubmodules];
    
	[self willChangeValueForKey:@"refs"];
	[self willChangeValueForKey:@"stashes"];
	[self didChangeValueForKey:@"refs"];
	[self didChangeValueForKey:@"stashes"];
}

- (void) lazyReload
{
	if (!hasChanged)
		return;

	[self.revisionList updateHistory];
	hasChanged = NO;
}

- (PBGitRevSpecifier *)headRef
{
	if (_headRef && _headOID)
		return _headRef;

	NSError *error = nil;
	GTReference *headRef = [self.gtRepo headReferenceWithError:&error];
	if (!headRef) {
		PBLogError(error);
		return nil;
	}

	GTReference *branchRef = [headRef resolvedReferenceWithError:&error];
	if (!branchRef) {
		PBLogError(error);
		return nil;
	}

	_headRef = [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:branchRef.name]];
	_headOID = branchRef.OID;

	return _headRef;
}

- (GTOID *)headOID
{
	if (! _headOID)
		[self headRef];

	return _headOID;
}

- (PBGitCommit *)headCommit
{
	return [self commitForOID:self.headOID];
}

- (GTOID *)OIDForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;
	
	for (GTOID *sha in refs)
	{
		NSMutableSet *refsForSha = [refs objectForKey:sha];
		for (PBGitRef *existingRef in refsForSha)
		{
			if ([existingRef isEqualToRef:ref])
			{
				return sha;
			}
		}
    }
    
	
	NSError* error = nil;
	GTReference *gtRef = [self.gtRepo lookUpReferenceWithName:ref.ref error:&error];
	if (!gtRef)
	{
		NSLog(@"Error looking up ref for %@", ref.ref);
		return nil;
	}
	return gtRef.OID;
}

- (PBGitCommit *)commitForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;

	return [self commitForOID:[self OIDForRef:ref]];
}

- (PBGitCommit *)commitForOID:(GTOID *)sha
{
	if (!sha)
		return nil;
	NSArray *revList = revisionList.projectCommits;

    if (!revList) {
        [revisionList forceUpdate];
        revList = revisionList.projectCommits;
    }
	for (PBGitCommit *commit in revList)
		if ([commit.OID isEqual:sha])
			return commit;

	return nil;
}

- (BOOL)isOIDOnSameBranch:(GTOID *)branchOID asOID:(GTOID *)testOID
{
	if (!branchOID || !testOID)
		return NO;

	if ([testOID isEqual:branchOID])
		return YES;

	NSArray *revList = revisionList.projectCommits;

	NSMutableSet *searchOIDs = [NSMutableSet setWithObject:branchOID];

	for (PBGitCommit *commit in revList) {
		GTOID *commitOID = commit.OID;
		if ([searchOIDs containsObject:commitOID]) {
			if ([testOID isEqual:commitOID])
				return YES;
			[searchOIDs removeObject:commitOID];
			[searchOIDs addObjectsFromArray:commit.parents];
		}
		else if ([testOID isEqual:commitOID])
			return NO;
	}

	return NO;
}

- (BOOL)isOIDOnHeadBranch:(GTOID *)testOID
{
	if (!testOID)
		return NO;

	GTOID *headOID = self.headOID;

	if ([testOID isEqual:headOID])
		return YES;

	return [self isOIDOnSameBranch:headOID asOID:testOID];
}

- (BOOL)isRefOnHeadBranch:(PBGitRef *)testRef
{
	if (!testRef)
		return NO;

	return [self isOIDOnHeadBranch:[self OIDForRef:testRef]];
}

- (BOOL) checkRefFormat:(NSString *)refName
{
	BOOL result = [GTReference isValidReferenceName:refName];
	return result;
}

- (BOOL) refExists:(PBGitRef *)ref
{
	NSError *gtError = nil;
	GTReference *gtRef = [self.gtRepo lookUpReferenceWithName:ref.ref error:&gtError];
	if (gtRef) {
		return YES;
	}
	return NO;
}

// useful for getting the full ref for a user entered name
// EX:  name: master
//       ref: refs/heads/master
- (PBGitRef *)refForName:(NSString *)name
{
	if (!name)
		return nil;

	NSError *taskError = nil;
	NSString *output = [self outputOfTaskWithArguments:@[@"show-ref", name] error:&taskError];

	// the output is in the format: <SHA-1 ID> <space> <reference name>
	// with potentially multiple lines if there are multiple matching refs (ex: refs/remotes/origin/master)
	// here we only care about the first match
	NSArray *refList = [output componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (refList.count != 1) return nil;

	NSString *refName = [refList objectAtIndex:1];
	return [PBGitRef refFromString:refName];
}

- (NSArray*)branches
{
    return [self.branchesSet array];
}
		
// Returns either this object, or an existing, equal object
- (PBGitRevSpecifier*) addBranch:(PBGitRevSpecifier*)branch
{
	if ([[branch parameters] count] == 0)
		branch = [self headRef];

	// First check if the branch doesn't exist already
    if ([self.branchesSet containsObject:branch]) {
        return branch;
    }

	NSIndexSet *newIndex = [NSIndexSet indexSetWithIndex:[self.branches count]];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:newIndex forKey:@"branches"];

    [self.branchesSet addObject:branch];

	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:newIndex forKey:@"branches"];
	return branch;
}

- (BOOL) removeBranch:(PBGitRevSpecifier *)branch
{
    if ([self.branchesSet containsObject:branch]) {
        NSIndexSet *oldIndex = [NSIndexSet indexSetWithIndex:[self.branches indexOfObject:branch]];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:oldIndex forKey:@"branches"];

        [self.branchesSet removeObject:branch];

        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:oldIndex forKey:@"branches"];
        return YES;
    }
	return NO;
}
	
- (void) readCurrentBranch
{
		self.currentBranch = [self addBranch: [self headRef]];
}

- (void) setCurrentBranch:(PBGitRevSpecifier *)newCurrentBranch {
	currentBranch = newCurrentBranch;
	[revisionList updateHistory];
}

- (void) setCurrentBranchFilter:(NSInteger)newCurrentBranchFilter {
	currentBranchFilter = newCurrentBranchFilter;
	[revisionList updateHistory];
}

- (void) setHasChanged:(BOOL)newHasChanged {
	hasChanged = newHasChanged;
	[revisionList forceUpdate];
}


#pragma mark Stashes

- (NSArray *)stashes
{
	NSMutableArray *stashes = [NSMutableArray array];
	[self.gtRepo enumerateStashesUsingBlock:^(NSUInteger index, NSString *message, GTOID *oid, BOOL *stop) {
		PBGitStash *stash = [[PBGitStash alloc] initWithRepository:self stashOID:oid index:index message:message];
		[stashes addObject:stash];
	}];
    return [NSArray arrayWithArray:stashes];
}

- (PBGitStash *)stashForRef:(PBGitRef *)ref {
    __block PBGitStash * found = nil;

	[self.gtRepo enumerateStashesUsingBlock:^(NSUInteger index, NSString *message, GTOID *oid, BOOL *stop) {
		PBGitStash *stash = [[PBGitStash alloc] initWithRepository:self stashOID:oid index:index message:message];
        if ([stash.ref isEqualToRef:ref]) {
            found = stash;
            *stop = YES;
        }
	}];
    return found;
}

- (BOOL)stashRunCommand:(NSString *)command withStash:(PBGitStash *)stash error:(NSError **)error
{
	NSError *gitError = nil;
    NSArray *arguments = @[@"stash", command, stash.ref.refishName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
    [self willChangeValueForKey:@"stashes"];
	[self didChangeValueForKey:@"stashes"];
	if (!output) {
		NSString *title = [NSString stringWithFormat:@"Stash %@ failed!", command];
		NSString *message = [NSString stringWithFormat:@"There was an error!"];

		return PBReturnErrorWithUserInfo(error, title, message, @{NSUnderlyingErrorKey: gitError});
    }
    return YES;
}

- (BOOL)stashPop:(PBGitStash *)stash error:(NSError **)error
{
    return [self stashRunCommand:@"pop" withStash:stash error:error];
}

- (BOOL)stashApply:(PBGitStash *)stash error:(NSError **)error
{
    return [self stashRunCommand:@"apply" withStash:stash error:error];
}

- (BOOL)stashDrop:(PBGitStash *)stash error:(NSError **)error
{
    return [self stashRunCommand:@"drop" withStash:stash error:error];
}

- (BOOL)stashSave:(NSError **)error
{
    return [self stashSaveWithKeepIndex:NO error:error];
}

- (BOOL)stashSaveWithKeepIndex:(BOOL)keepIndex error:(NSError **)error
{
	NSError *gitError = nil;
    NSArray * arguments = @[@"stash", @"save", keepIndex?@"--keep-index":@"--no-keep-index"];

	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
    [self willChangeValueForKey:@"stashes"];
	[self didChangeValueForKey:@"stashes"];
    if (!output) {
		NSString *title = [NSString stringWithFormat:@"Stash save failed!"];
		NSString *message = [NSString stringWithFormat:@"There was an error!"];

		return PBReturnErrorWithUserInfo(error, title, message, @{NSUnderlyingErrorKey: gitError});
    }
    return YES;
}

- (BOOL)ignoreFilePaths:(NSArray *)filePaths error:(NSError **)error
{
	NSString *filesAsString = [filePaths componentsJoinedByString:@"\n"];

	// Write to the file
	NSString *gitIgnoreName = [self gitIgnoreFilename];

	NSStringEncoding enc = NSUTF8StringEncoding;
	NSString *ignoreFile;

	if (![[NSFileManager defaultManager] fileExistsAtPath:gitIgnoreName]) {
		ignoreFile = filesAsString;
	} else {
		NSMutableString *currentFile = [NSMutableString stringWithContentsOfFile:gitIgnoreName usedEncoding:&enc error:error];
		if (!currentFile) return NO;

		// Add a newline if not yet present
		if ([currentFile characterAtIndex:([ignoreFile length] - 1)] != '\n')
			[currentFile appendString:@"\n"];
		[currentFile appendString:filesAsString];

		ignoreFile = currentFile;
	}

	return [ignoreFile writeToFile:gitIgnoreName atomically:YES encoding:enc error:error];
}

- (PBGitIndex *)index
{
	if (!_index) {
		_index = [[PBGitIndex alloc] initWithRepository:self];
	}
	return _index;
}

#pragma mark Remotes

- (NSArray *) remotes
{
	NSError *error = nil;
	NSArray *remotes = [self.gtRepo remoteNamesWithError:&error];
	if (!remotes) {
		PBLogError(error);
		return nil;
	}
	return remotes;
}

- (BOOL) hasRemotes
{
	return ([self remotes] != nil);
}

- (PBGitRef *) remoteRefForBranch:(PBGitRef *)branch error:(NSError **)error
{
	if ([branch isRemote]) {
		return [branch remoteRef];
	}

	NSError *gtError = nil;
	BOOL success = NO;
	NSAssert(branch.ref != nil, @"Unexpected nil ref");

	GTBranch *gtBranch = [self.gtRepo lookUpBranchWithName:branch.branchName type:GTBranchTypeLocal success:&success error:&gtError];
	if (!success) {
		NSString *failure = [NSString stringWithFormat:NSLocalizedString(@"There was an error looking up the branch \"%@\"", @""), branch.shortName];
		PBReturnError(error, NSLocalizedString(@"Branch lookup failed", @""), failure, gtError);
		return nil;
	}
	if (!gtBranch) {
		NSString *failure = [NSString stringWithFormat:NSLocalizedString(@"There doesn't seem to be a branch named \"%@\"", @""), branch.shortName];
		PBReturnError(error, NSLocalizedString(@"Branch lookup failed", @""), failure, gtError);
		return nil;
	}

	GTBranch *trackingBranch = [gtBranch trackingBranchWithError:&gtError success:&success];
	if (!success) {
		NSString *failure = [NSString stringWithFormat:NSLocalizedString(@"There was an error finding the tracking branch of branch \"%@\"", @""), branch.shortName];
		PBReturnError(error, NSLocalizedString(@"Branch lookup failed", @""), failure, gtError);
		return nil;
	}
	if (!trackingBranch) {
		PBReturnErrorWithBuilder(error, ^{
			NSString *info = [NSString stringWithFormat:@"There is no remote configured for branch \"%@\".", branch.shortName];
			NSString *recovery = NSLocalizedString(@"Please select a branch from the popup menu, which has a corresponding remote tracking branch set up.\n\nYou can also use a contextual menu to choose a branch by right clicking on its label in the commit history list.", @"");

			return [NSError pb_errorWithDescription:NSLocalizedString(@"No remote configured for branch", @"")
										failureReason:info
									  underlyingError:gtError
											 userInfo:@{NSLocalizedRecoverySuggestionErrorKey: recovery}];
		});
		return nil;
	}

	NSString *trackingBranchRefName = trackingBranch.reference.name;
	PBGitRef *trackingBranchRef = [PBGitRef refFromString:trackingBranchRefName];
	return trackingBranchRef;
}

#pragma mark Repository commands

- (BOOL)addRemote:(NSString *)remoteName withURL:(NSString *)URLString error:(NSError **)error
{
	PBTask *task = [self taskWithArguments:@[@"remote", @"add", @"-f", remoteName, URLString]];
	return [task launchTask:error];
}

- (BOOL)fetchRemoteForRef:(PBGitRef *)ref error:(NSError **)error
{
	NSString *fetchArg = nil;
	if (ref == nil) {
		fetchArg = @"--all";
	} else {
		if (!ref.isRemote) {
			ref = [self remoteRefForBranch:ref error:error];
			if (!ref) return NO;
		}
		fetchArg = ref.remoteName;
	}

	PBTask *task = [self taskWithArguments:@[@"fetch", fetchArg]];
	NSError *taskError = nil;
	BOOL success = [task launchTask:&taskError];
	if (!success) {
		NSString *desc = NSLocalizedString(@"Fetch failed", @"PBGitRepository - push error description");
		NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"An error occurred while fetching remote \"%@\".", @"PBGitRepostory - push error reason"), ref.remoteName];
		PBReturnError(error, desc, reason, taskError);
	}


	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadRefs];
	});

	return success;
}

- (BOOL)pullBranch:(PBGitRef *)branchRef fromRemote:(PBGitRef *)remoteRef rebase:(BOOL)rebase error:(NSError **)error
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"pull"];

	if (rebase) {
		[arguments addObject:@"--rebase"];
	}

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:branchRef error:&error];
		if (!remoteRef) return NO;
	}
	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];

	PBTask *task = [self taskWithArguments:arguments];
	NSError *taskError = nil;
	BOOL success = [task launchTask:error];
	if (!success) {
		NSString *desc = NSLocalizedString(@"Pull failed", @"PBGitRepository - push error description");
		NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"An error occurred while pulling remote \"%@\" to \"%@\".", @"PBGitRepostory - push error reason"), remoteName, branchRef.shortName];
		PBReturnError(error, desc, reason, taskError);
	}


	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadRefs];
	});

	return success;
}

- (BOOL)pushBranch:(PBGitRef *)branchRef toRemote:(PBGitRef *)remoteRef error:(NSError **)error
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"push"];

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:branchRef error:&error];
		if (!remoteRef) return NO;
	}

	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];

	NSString *branchName = nil;
	if (!branchRef || branchRef.isRemote) {
		branchName = @"all updates";
	} else if (branchRef.isTag) {
		branchName = [NSString stringWithFormat:@"tag '%@'", [branchRef tagName]];
		[arguments addObject:@"tag"];
		[arguments addObject:[branchRef tagName]];
	} else {
		branchName = [branchRef shortName];
		[arguments addObject:branchName];
	}

	PBTask *task = [self taskWithArguments:arguments];

	NSError *taskError = nil;
	BOOL success = [task launchTask:&taskError];
	if (!success) {
		NSString *desc = NSLocalizedString(@"Push failed", @"PBGitRepository - push error description");
		NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"An error occurred while pushing %@ to \"%@\".", @"PBGitRepostory - push error reason"), branchName, remoteName];
		PBReturnError(error, desc, reason, taskError);
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadRefs];
	});

	return success;
}

- (BOOL) checkoutRefish:(id <PBGitRefish>)ref error:(NSError **)error
{
	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	NSError *gitError = nil;
	NSArray *arguments = @[@"checkout", refName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Checkout failed";
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];

		return PBReturnError(error, title, message, gitError);
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) checkoutFiles:(NSArray *)files fromRefish:(id <PBGitRefish>)ref error:(NSError **)error
{
	if (!files || ([files count] == 0))
		return NO;

	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	NSArray *arguments = @[@"checkout", refName, @"--"];
	arguments = [arguments arrayByAddingObjectsFromArray:files];

	NSError *gitError = nil;
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Checkout failed";
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the file(s) from the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];

		return PBReturnError(error, title, message, gitError);
	}

	return YES;
}


- (BOOL) mergeWithRefish:(id <PBGitRefish>)ref error:(NSError **)error
{
	NSString *refName = [ref refishName];

	NSError *gitError = nil;
	NSArray *arguments = @[@"merge", refName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Merge failed!";
		NSString *headName = [[[self headRef] ref] shortName];
		NSString *message = [NSString stringWithFormat:@"There was an error merging %@ into %@.", refName, headName];

		return PBReturnError(error, title, message, gitError);
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) cherryPickRefish:(id <PBGitRefish>)ref error:(NSError **)error
{
	if (!ref)
		return NO;

	NSString *refName = [ref refishName];

	NSError *gitError = nil;
	NSArray *arguments = @[@"cherry-pick", refName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Cherry pick failed!";
		NSString *message = [NSString stringWithFormat:@"There was an error cherry picking the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];

		return PBReturnError(error, title, message, gitError);
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) rebaseBranch:(id <PBGitRefish>)branch onRefish:(id <PBGitRefish>)upstream error:(NSError **)error
{
	if (!upstream)
		return NO;

	NSArray *arguments = @[@"rebase", upstream.refishName];

	if (branch)
		arguments = [arguments arrayByAddingObject:branch.refishName];

	NSError *gitError = nil;
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *branchName = @"HEAD";
		if (branch)
			branchName = [NSString stringWithFormat:@"%@ '%@'", [branch refishType], [branch shortName]];
		NSString *title = @"Rebase failed!";
		NSString *message = [NSString stringWithFormat:@"There was an error rebasing %@ with %@ '%@'.", branchName, [upstream refishType], [upstream shortName]];

		return PBReturnError(error, title, message, gitError);
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) createBranch:(NSString *)branchName atRefish:(id <PBGitRefish>)ref error:(NSError **)error
{
	if (!branchName || !ref)
		return NO;

	NSError *gitError = nil;
	NSArray *arguments = @[@"branch", branchName, ref.refishName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Create Branch failed!";
		NSString *message = [NSString stringWithFormat:@"There was an error creating the branch '%@' at %@ '%@'.", branchName, [ref refishType], [ref shortName]];

		return PBReturnErrorWithUserInfo(error, title, message, @{NSUnderlyingErrorKey: gitError});
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) createTag:(NSString *)tagName message:(NSString *)message atRefish:(id <PBGitRefish>)target error:(NSError **)error
{
	if (!tagName)
		return NO;

	GTObject *object = [self.gtRepo lookUpObjectByRevParse:[target refishName] error:error];
	if (!object) return NO;

	GTTag *newTag  = [self.gtRepo createTagNamed:tagName target:object tagger:self.gtRepo.userSignatureForNow message:message error:error];
	if (!newTag) return NO;

	[self reloadRefs];
	return YES;
}

- (BOOL) deleteRemote:(PBGitRef *)ref error:(NSError **)error
{
	if (!ref || ([ref refishType] != kGitXRemoteType))
		return NO;

	NSError *gitError = nil;
	NSArray *arguments = @[@"remote", @"rm", ref.remoteName];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Delete remote failed!";
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the remote: %@\n\n", [ref remoteName]];
		return PBReturnErrorWithUserInfo(error, title, message, @{NSUnderlyingErrorKey: gitError});
	}

	// remove the remote's branches
	NSString *remoteRef = [kGitXRemoteRefPrefix stringByAppendingString:[ref remoteName]];
	for (PBGitRevSpecifier *rev in [self.branchesSet copy]) {
		PBGitRef *branch = [rev ref];
		if ([[branch ref] hasPrefix:remoteRef]) {
			[self removeBranch:rev];
			PBGitCommit *commit = [self commitForRef:branch];
			[commit removeRef:branch];
		}
	}

	[self reloadRefs];
	return YES;
}

- (NSString *)performDiff:(PBGitCommit *)startCommit against:(PBGitCommit *)diffCommit forFiles:(NSArray *)filePaths {
	NSParameterAssert(startCommit);
	NSAssert(startCommit.repository == self, @"Different repo");

	if (diffCommit) {
		NSAssert(diffCommit.repository == self, @"Different repo");
	} else {
		diffCommit = [self headCommit];
	}

	NSString *commitSelector = [NSString stringWithFormat:@"%@..%@", startCommit.SHA, diffCommit.SHA];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"diff", @"--no-ext-diff", commitSelector, nil];

	if (![PBGitDefaults showWhitespaceDifferences])
		[arguments insertObject:@"-w" atIndex:1];

	if (filePaths) {
		[arguments addObject:@"--"];
		[arguments addObjectsFromArray:filePaths];
	}

	NSError *error = nil;
	NSString *diff = [self outputOfTaskWithArguments:arguments error:&error];
	if (!diff) {
		PBLogError(error);
		return @"";
	}
	return diff;
}

- (BOOL) deleteRef:(PBGitRef *)ref error:(NSError **)error
{
	if (!ref)
		return NO;

	if ([ref refishType] == kGitXRemoteType)
		return [self deleteRemote:ref error:error];

	NSError *gitError = nil;
	NSArray *arguments = @[@"update-ref", @"-d", ref.ref];
	NSString *output = [self outputOfTaskWithArguments:arguments error:&gitError];
	if (!output) {
		NSString *title = @"Delete ref failed!";
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the ref: %@\n\n", [ref shortName]];

		return PBReturnErrorWithUserInfo(error, title, message, @{NSUnderlyingErrorKey: gitError});
	}

	[self removeBranch:[[PBGitRevSpecifier alloc] initWithRef:ref]];
	PBGitCommit *commit = [self commitForRef:ref];
	[commit removeRef:ref];

	[self reloadRefs];
	return YES;
}

- (BOOL)updateReference:(PBGitRef *)ref toPointAtCommit:(PBGitCommit *)newCommit {
	NSError *error = nil;
	BOOL success = [self launchTaskWithArguments:@[@"update-ref", @"-mUpdate from GitX", ref.ref, newCommit.SHA] error:&error];
	if (!success) {
		PBLogError(error);
	}
	return success;
}

- (GTSubmodule *)submoduleAtPath:(NSString *)path error:(NSError **)error;
{
	NSString *standardizedPath = path.stringByStandardizingPath;
	for (GTSubmodule *submodule in self.submodules) {
		if ([standardizedPath hasSuffix:submodule.path]) {
			return submodule;
		}
	}
	if (error) {
		NSString *failure = [NSString stringWithFormat:@"The submodule at path \"%@\" couldn't be found.", path];
		*error = [NSError pb_errorWithDescription:@"Submodule not found" failureReason:failure];
	}
	return nil;
}

#pragma mark Hooks

- (BOOL)executeHook:(NSString *)name output:(NSString **)output {
	return [self executeHook:name withArgs:[NSArray array] output:output];
}

- (BOOL)executeHook:(NSString *)name withArgs:(NSArray *)arguments output:(NSString **)outputPtr {
	return [self executeHook:name arguments:arguments output:outputPtr error:NULL];
}

- (BOOL)executeHook:(NSString *)name error:(NSError **)error {
	return [self executeHook:name arguments:@[] error:error];
}

- (BOOL)executeHook:(NSString *)name arguments:(NSArray *)arguments error:(NSError **)error {
	return [self executeHook:name arguments:arguments output:NULL error:error];
}

- (BOOL)executeHook:(NSString *)name arguments:(NSArray *)arguments output:(NSString **)outputPtr error:(NSError **)error {
	NSParameterAssert(name != nil);

	NSString *hookPath = [[[[self gitURL] path] stringByAppendingPathComponent:@"hooks"] stringByAppendingPathComponent:name];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:hookPath]) {
		// XXX: Maybe return error ?
		return YES;
	}

	PBTask *task = [PBTask taskWithLaunchPath:hookPath arguments:arguments inDirectory:self.workingDirectory];
	task.additionalEnvironment = @{
								   @"GIT_DIR": self.gitURL.path,
								   @"GIT_INDEX_FILE": [self.gitURL.path stringByAppendingPathComponent:@"index"],
								   };

	NSError *taskError = nil;
	BOOL success = [task launchTask:&taskError];

	NSString *output = task.standardOutputString;
	if (!success) {
		return PBReturnErrorWithBuilder(error, ^{
			NSString *failureReason = [NSString localizedStringWithFormat:@"Hook %@ failed", name];
			NSString *desc = nil;
			if (output.length == 0) {
				desc = [NSString localizedStringWithFormat:@"The %@ hook failed to run.", name];
			} else {
				desc = [NSString localizedStringWithFormat:@"The %@ hook failed to run and returned the following:\n%@", name, output];
			}
			return [NSError pb_errorWithDescription:desc failureReason:failureReason underlyingError:taskError];
		});
	}

	if (outputPtr) *outputPtr = output;

	return YES;
}

- (BOOL)revisionExists:(NSString *)spec
{
	return [self.gtRepo lookUpObjectByRevParse:spec error:nil] != nil;
}

@end
