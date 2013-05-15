//
//  PBGitRepository.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitWindowController.h"
#import "PBGitBinary.h"

#import "NSFileHandleExt.h"
#import "PBEasyPipe.h"
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"
#import "PBRemoteProgressSheet.h"
#import "PBGitRevList.h"
#import "PBGitDefaults.h"
#import "GitXScriptingConstants.h"
#import "PBHistorySearchController.h"
#import "PBGitRepositoryWatcher.h"
#import "GitRepoFinder.h"
#import "PBGitSubmodule.h"

#import <ObjectiveGit/GTRepository.h>
#import <ObjectiveGit/GTIndex.h>
#import <ObjectiveGit/GTConfiguration.h>

@implementation PBGitRepository

@synthesize revisionList, branchesSet, currentBranch, refs, hasChanged, configuration, submodules;
@synthesize currentBranchFilter;

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if (outError) {
		*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain
                                      code:0
                                  userInfo:[NSDictionary dictionaryWithObject:@"Reading files is not supported." forKey:NSLocalizedFailureReasonErrorKey]];
	}
	return NO;
}

+ (BOOL) isBareRepository: (NSURL*) url
{
	NSError* pError;
	GTRepository* gitRepo = [[GTRepository alloc] initWithURL:url error:&pError];

	return gitRepo && git_repository_is_bare([gitRepo git_repository]);
}

- (BOOL) isBareRepository
{
	return [PBGitRepository isBareRepository:[self fileURL]];
}

// NSFileWrapper is broken and doesn't work when called on a directory containing a large number of directories and files.
//because of this it is safer to implement readFromURL than readFromFileWrapper.
//Because NSFileManager does not attempt to recursively open all directories and file when fileExistsAtPath is called
//this works much better.
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if (![PBGitBinary path])
	{
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[PBGitBinary notFoundError]
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}

	BOOL isDirectory = FALSE;
	[[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path] isDirectory:&isDirectory];
	if (!isDirectory) {
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:@"Reading files is not supported."
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}


	NSURL* gitDirURL = [GitRepoFinder gitDirForURL:absoluteURL];
	if (!gitDirURL) {
		if (outError) {
			NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@ does not appear to be a git repository.", [[self fileURL] path]]
																 forKey:NSLocalizedRecoverySuggestionErrorKey];
			*outError = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}
	self.fileURL = [GitRepoFinder fileURLForURL:absoluteURL];

	[self setup];
  watcher = [[PBGitRepositoryWatcher alloc] initWithRepository:self];
	return YES;
}

- (NSURL *) gitURL {
    return self.gtRepo.gitDirectoryURL;
}
- (void) setup
{
	self->configuration = self.gtRepo.configuration;
	self.branchesSet = [NSMutableOrderedSet orderedSet];
    self.submodules = [NSMutableArray array];
	[self reloadRefs];
	currentBranchFilter = [PBGitDefaults branchFilter];
	revisionList = [[PBGitHistoryList alloc] initWithRepository:self];
}

- (void)close
{
	[revisionList cleanup];

	[super close];
}

- (id) initWithURL: (NSURL*) path
{
	if (![PBGitBinary path])
		return nil;

	NSURL* gitDirURL = [GitRepoFinder gitDirForURL:path];
	if (!gitDirURL)
		return nil;

	self = [self init];
	if (!self)
	{
		NSLog(@"Failed to initWithURL:%@", path);
		return nil;
	}
    
	[self setFileURL: path];

	[self setup];
	
	// We don't want the window controller to display anything yet..
	// We'll leave that to the caller of this method.
#ifndef CLI
	[self addWindowController:[[PBGitWindowController alloc] initWithRepository:self displayDefault:NO]];
#endif

	[self showWindows];
    
  // Setup the FSEvents watcher to fire notifications when things change
  watcher = [[PBGitRepositoryWatcher alloc] initWithRepository:self];
	return self;
}

- (void) forceUpdateRevisions
{
	[revisionList forceUpdate];
}

- (BOOL)isDocumentEdited
{
	return NO;
}

// The fileURL the document keeps is to the working dir
- (NSString *) displayName
{
	if (![[PBGitRef refFromString:[[self headRef] simpleRef]] type])
		return [NSString stringWithFormat:@"%@ (detached HEAD)", [self projectName]];

	return [NSString stringWithFormat:@"%@ (branch: %@)", [self projectName], [[self headRef] description]];
}

- (NSString *) projectName
{
	NSString* result = [self.workingDirectory lastPathComponent];
	return result;
}

// Get the .gitignore file at the root of the repository
- (NSString*)gitIgnoreFilename
{
	return [[self workingDirectory] stringByAppendingPathComponent:@".gitignore"];
}

// Overridden to create our custom window controller
- (void)makeWindowControllers
{
#ifndef CLI
	[self addWindowController: [[PBGitWindowController alloc] initWithRepository:self displayDefault:YES]];
#endif
}

- (PBGitWindowController *)windowController
{
	if ([[self windowControllers] count] == 0)
		return NULL;
	
	return [[self windowControllers] objectAtIndex:0];
}

- (void) addRef:(GTReference*)gtRef
{
	if (gtRef == nil)
	{
		NSLog(@"Sneaky attempt to add nil GTReference");
		return;
	}
	if (!([gtRef.type compare:@"commit"] == NSOrderedSame||
		 [gtRef.type compare:@"tag"] == NSOrderedSame))
	{
//		NSLog(@"Can't addRef for %@ ref of unsupported type \"%@\"", gtRef.name, gtRef.type);
		return;
	}
	
	git_oid refOid = *(gtRef.oid);
	git_object* gitTarget = NULL;
	git_tag* gitTag = NULL;
	PBGitSHA *sha = [PBGitSHA shaWithOID:refOid];
	if (git_tag_lookup(&gitTag, self.gtRepo.git_repository, gtRef.oid) == GIT_OK)
	{
		if (git_tag_peel(&gitTarget, gitTag) == GIT_OK)
		{
			GTObject* peeledObject = [GTObject objectWithObj:gitTarget inRepository:self.gtRepo];
//			NSLog(@"peeled sha:%@", peeledObject.sha);
			sha = [PBGitSHA shaWithString:peeledObject.sha];
		}
	}
	
	PBGitRef* ref = [[PBGitRef alloc] initWithString:gtRef.name];
//	NSLog(@"addRef %@ %@ at %@", ref.type, gtRef.name, [sha string]);
	NSMutableArray* curRefs;
	if ( (curRefs = [refs objectForKey:sha]) != nil )
		[curRefs addObject:ref];
	else
		[refs setObject:[NSMutableArray arrayWithObject:ref] forKey:sha];
}

int addSubmoduleName(git_submodule *module, const char* name, void * context)
{
    PBGitRepository *me = (__bridge PBGitRepository *)context;
    PBGitSubmodule *sub = [[PBGitSubmodule alloc] init];
    [sub setWorkingDirectory:me.workingDirectory];
    [sub setSubmodule:module];
    

    [me.submodules addObject:sub];
    
    return 0;
}

- (void) loadSubmodules
{
    self.submodules = [NSMutableArray array];
	git_repository* theRepo = self.gtRepo.git_repository;
	if (!theRepo)
	{
		return;
	}
    git_submodule_foreach(theRepo, addSubmoduleName, (__bridge void *)self);
}

- (void) reloadRefs
{
	// clear out ref caches
	_headRef = nil;
	_headSha = nil;
	self->refs = [NSMutableDictionary dictionary];
	
	NSError* error = nil;
	NSArray* allRefs = [self.gtRepo referenceNamesWithError:&error];
	
	// load all named refs
	NSMutableOrderedSet *oldBranches = [self.branchesSet mutableCopy];
	for (NSString* referenceName in allRefs)
	{
		GTReference* gtRef =
		[[GTReference alloc] initByLookingUpReferenceNamed:referenceName
											  inRepository:self.gtRepo
													 error:&error];
		
		if (gtRef == nil)
		{
			NSLog(@"Reference \"%@\" could not be found in the repository", referenceName);
			if (error)
			{
				NSLog(@"Error loading reference was: %@", error);
			}
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
	[self didChangeValueForKey:@"refs"];

	[[[self windowController] window] setTitle:[self displayName]];
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
	if (_headRef)
		return _headRef;

	NSString* branch = [self parseSymbolicReference: @"HEAD"];
	if (branch && [branch hasPrefix:@"refs/heads/"])
		_headRef = [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:branch]];
	else
		_headRef = [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:@"HEAD"]];

	_headSha = [self shaForRef:[_headRef ref]];

	return _headRef;
}

- (PBGitSHA *)headSHA
{
	if (! _headSha)
		[self headRef];

	return _headSha;
}

- (PBGitCommit *)headCommit
{
	return [self commitForSHA:[self headSHA]];
}

- (PBGitSHA *)shaForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;
	
	for (PBGitSHA *sha in refs)
	{
		for (PBGitRef *existingRef in [refs objectForKey:sha])
		{
			if ([existingRef isEqualToRef:ref])
			{
				return sha;
			}
		}
    }
    
	
	NSError* error = nil;
	GTReference* gtRef = [GTReference referenceByLookingUpReferencedNamed:ref.ref
															 inRepository:self.gtRepo
																	error:&error];
	if (error)
	{
		NSLog(@"Error looking up ref for %@", ref.ref);
		return nil;
	}
	const git_oid* refOid = gtRef.oid;
	
	if (refOid)
	{
		char buffer[41];
		buffer[40] = '\0';
		git_oid_fmt(buffer, refOid);
		NSString* shaForRef = [NSString stringWithUTF8String:buffer];
		PBGitSHA* result = [PBGitSHA shaWithString:shaForRef];
		return result;
	}
	return nil;
}

- (PBGitCommit *)commitForRef:(PBGitRef *)ref
{
	if (!ref)
		return nil;

	return [self commitForSHA:[self shaForRef:ref]];
}

- (PBGitCommit *)commitForSHA:(PBGitSHA *)sha
{
	if (!sha)
		return nil;
	NSArray *revList = revisionList.projectCommits;

    if (!revList) {
        [revisionList forceUpdate];
        revList = revisionList.projectCommits;
    }
	for (PBGitCommit *commit in revList)
		if ([[commit sha] isEqual:sha])
			return commit;

	return nil;
}

- (BOOL)isOnSameBranch:(PBGitSHA *)branchSHA asSHA:(PBGitSHA *)testSHA
{
	if (!branchSHA || !testSHA)
		return NO;

	if ([testSHA isEqual:branchSHA])
		return YES;

	NSArray *revList = revisionList.projectCommits;

	NSMutableSet *searchSHAs = [NSMutableSet setWithObject:branchSHA];

	for (PBGitCommit *commit in revList) {
		PBGitSHA *commitSHA = [commit sha];
		if ([searchSHAs containsObject:commitSHA]) {
			if ([testSHA isEqual:commitSHA])
				return YES;
			[searchSHAs removeObject:commitSHA];
			[searchSHAs addObjectsFromArray:commit.parents];
		}
		else if ([testSHA isEqual:commitSHA])
			return NO;
	}

	return NO;
}

- (BOOL)isSHAOnHeadBranch:(PBGitSHA *)testSHA
{
	if (!testSHA)
		return NO;

	PBGitSHA *headSHA = [self headSHA];

	if ([testSHA isEqual:headSHA])
		return YES;

	return [self isOnSameBranch:headSHA asSHA:testSHA];
}

- (BOOL)isRefOnHeadBranch:(PBGitRef *)testRef
{
	if (!testRef)
		return NO;

	return [self isSHAOnHeadBranch:[self shaForRef:testRef]];
}

- (BOOL) checkRefFormat:(NSString *)refName
{
	int retValue = 1;
	[self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"check-ref-format", refName, nil] retValue:&retValue];
	if (retValue)
		return NO;
	return YES;
}

- (BOOL) refExists:(PBGitRef *)ref
{
	int retValue = 1;
    NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"for-each-ref", [ref ref], nil] retValue:&retValue];
    if (retValue || [output isEqualToString:@""])
        return NO;
    return YES;
}

// useful for getting the full ref for a user entered name
// EX:  name: master
//       ref: refs/heads/master
- (PBGitRef *)refForName:(NSString *)name
{
	if (!name)
		return nil;

	int retValue = 1;
    NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"show-ref", name, nil] retValue:&retValue];
	if (retValue)
		return nil;

	// the output is in the format: <SHA-1 ID> <space> <reference name>
	// with potentially multiple lines if there are multiple matching refs (ex: refs/remotes/origin/master)
	// here we only care about the first match
	NSArray *refList = [output componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([refList count] > 1) {
		NSString *refName = [refList objectAtIndex:1];
		return [PBGitRef refFromString:refName];
	}

	return nil;
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

- (NSString *) workingDirectory
{
	const char* workdir = git_repository_workdir(self.gtRepo.git_repository);
	if (workdir)
	{
		NSString* result = [[NSString stringWithUTF8String:workdir] stringByStandardizingPath];
		return result;
	}
    else
	{
        return self.fileURL.path;
	}
}

#pragma mark Remotes

- (NSArray *) remotes
{
	int retValue = 1;
	NSString *remotes = [self outputInWorkdirForArguments:[NSArray arrayWithObject:@"remote"] retValue:&retValue];
	if (retValue || [remotes isEqualToString:@""])
		return nil;

	return [remotes componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (BOOL) hasRemotes
{
	return ([self remotes] != nil);
}

- (PBGitRef *) remoteRefForBranch:(PBGitRef *)branch error:(NSError **)error
{
	if ([branch isRemote])
		return [branch remoteRef];

	NSString *branchName = [branch branchName];
	if (branchName) {
		NSString *remoteName = [self.configuration stringForKey:[NSString stringWithFormat:@"branch.%@.remote", branchName]];
		if (remoteName && ([remoteName isKindOfClass:[NSString class]] && ![remoteName isEqualToString:@""])) {
			PBGitRef *remoteRef = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:remoteName]];
			// check that the remote is a valid ref and exists
			if ([self checkRefFormat:[remoteRef ref]] && [self refExists:remoteRef])
				return remoteRef;
		}
	}

	if (error != NULL) {
		NSString *info = [NSString stringWithFormat:@"There is no remote configured for the %@ '%@'.\n\nPlease select a branch from the popup menu, which has a corresponding remote tracking branch set up.\n\nYou can also use a contextual menu to choose a branch by right clicking on its label in the commit history list.", [branch refishType], [branch shortName]];
		*error = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0
								 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										   @"No remote configured for branch", NSLocalizedDescriptionKey,
										   info, NSLocalizedRecoverySuggestionErrorKey,
										   nil]];
	}
	return nil;
}

- (NSString *) infoForRemote:(NSString *)remoteName
{
	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:[NSArray arrayWithObjects:@"remote", @"show", remoteName, nil] retValue:&retValue];
	if (retValue)
		return nil;

	return output;
}

#pragma mark Repository commands

- (void) cloneRepositoryToPath:(NSString *)path bare:(BOOL)isBare
{
	if (!path || [path isEqualToString:@""])
		return;

	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"clone", @"--no-hardlinks", @"--", @".", path, nil];
	if (isBare)
		[arguments insertObject:@"--bare" atIndex:1];

	NSString *description = [NSString stringWithFormat:@"Cloning the repository %@ to %@", [self projectName], path];
	NSString *title = @"Cloning Repository";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginAddRemote:(NSString *)remoteName forURL:(NSString *)remoteURL
{
	NSArray *arguments = [NSArray arrayWithObjects:@"remote",  @"add", @"-f", remoteName, remoteURL, nil];

	NSString *description = [NSString stringWithFormat:@"Adding the remote %@ and fetching tracking branches", remoteName];
	NSString *title = @"Adding a remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginFetchFromRemoteForRef:(PBGitRef *)ref
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"fetch"];

	if (![ref isRemote]) {
		NSError *error = nil;
		ref = [self remoteRefForBranch:ref error:&error];
		if (!ref) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [ref remoteName];
	[arguments addObject:remoteName];

	NSString *description = [NSString stringWithFormat:@"Fetching all tracking branches from %@", remoteName];
	NSString *title = @"Fetching from remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self];
}

- (void) beginPullFromRemote:(PBGitRef *)remoteRef forRef:(PBGitRef *)ref
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"pull"];

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:ref error:&error];
		if (!remoteRef) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];

	NSString *description = [NSString stringWithFormat:@"Pulling all tracking branches from %@", remoteName];
	NSString *title = @"Pulling from remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self hideSuccessScreen:true];
}

- (void) beginPushRef:(PBGitRef *)ref toRemote:(PBGitRef *)remoteRef
{
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"push"];

	// a nil remoteRef means lookup the ref's default remote
	if (!remoteRef || ![remoteRef isRemote]) {
		NSError *error = nil;
		remoteRef = [self remoteRefForBranch:ref error:&error];
		if (!remoteRef) {
			if (error)
				[self.windowController showErrorSheet:error];
			return;
		}
	}
	NSString *remoteName = [remoteRef remoteName];
	[arguments addObject:remoteName];

	NSString *branchName = nil;
	if ([ref isRemote] || !ref) {
		branchName = @"all updates";
	}
	else if ([ref isTag]) {
		branchName = [NSString stringWithFormat:@"tag '%@'", [ref tagName]];
		[arguments addObject:@"tag"];
		[arguments addObject:[ref tagName]];
	}
	else {
		branchName = [ref shortName];
		[arguments addObject:branchName];
	}

	NSString *description = [NSString stringWithFormat:@"Pushing %@ to %@", branchName, remoteName];
	NSString *title = @"Pushing to remote";
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:arguments title:title description:description inRepository:self hideSuccessScreen:true];
}

- (BOOL) checkoutRefish:(id <PBGitRefish>)ref
{
	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"checkout", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Checkout failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) checkoutFiles:(NSArray *)files fromRefish:(id <PBGitRefish>)ref
{
	if (!files || ([files count] == 0))
		return NO;

	NSString *refName = nil;
	if ([ref refishType] == kGitXBranchType)
		refName = [ref shortName];
	else
		refName = [ref refishName];

	int retValue = 1;
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"checkout", refName, @"--", nil];
	[arguments addObjectsFromArray:files];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error checking out the file(s) from the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Checkout failed!" message:message arguments:arguments output:output];
		return NO;
	}

	return YES;
}


- (BOOL) mergeWithRefish:(id <PBGitRefish>)ref
{
	NSString *refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"merge", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *headName = [[[self headRef] ref] shortName];
		NSString *message = [NSString stringWithFormat:@"There was an error merging %@ into %@.", refName, headName];
		[self.windowController showErrorSheetTitle:@"Merge failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) cherryPickRefish:(id <PBGitRefish>)ref
{
	if (!ref)
		return NO;

	NSString *refName = [ref refishName];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"cherry-pick", refName, nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error cherry picking the %@ '%@'.\n\nPerhaps your working directory is not clean?", [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Cherry pick failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) rebaseBranch:(id <PBGitRefish>)branch onRefish:(id <PBGitRefish>)upstream
{
	if (!upstream)
		return NO;

	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"rebase", [upstream refishName], nil];

	if (branch)
		[arguments addObject:[branch refishName]];

	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *branchName = @"HEAD";
		if (branch)
			branchName = [NSString stringWithFormat:@"%@ '%@'", [branch refishType], [branch shortName]];
		NSString *message = [NSString stringWithFormat:@"There was an error rebasing %@ with %@ '%@'.", branchName, [upstream refishType], [upstream shortName]];
		[self.windowController showErrorSheetTitle:@"Rebase failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	[self readCurrentBranch];
	return YES;
}

- (BOOL) createBranch:(NSString *)branchName atRefish:(id <PBGitRefish>)ref
{
	if (!branchName || !ref)
		return NO;

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"branch", branchName, [ref refishName], nil];
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error creating the branch '%@' at %@ '%@'.", branchName, [ref refishType], [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Create Branch failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) createTag:(NSString *)tagName message:(NSString *)message atRefish:(id <PBGitRefish>)target
{
	if (!tagName)
		return NO;

	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"tag"];

	// if there is a message then make this an annotated tag
	if (message && ![message isEqualToString:@""] && ([message length] > 3)) {
		[arguments addObject:@"-a"];
		[arguments addObject:[@"-m" stringByAppendingString:message]];
	}

	[arguments addObject:tagName];

	// if no refish then git will add it to HEAD
	if (target)
		[arguments addObject:[target refishName]];

	int retValue = 1;
	NSString *output = [self outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *targetName = @"HEAD";
		if (target)
			targetName = [NSString stringWithFormat:@"%@ '%@'", [target refishType], [target shortName]];
		NSString *message = [NSString stringWithFormat:@"There was an error creating the tag '%@' at %@.", tagName, targetName];
		[self.windowController showErrorSheetTitle:@"Create Tag failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self reloadRefs];
	return YES;
}

- (BOOL) deleteRemote:(PBGitRef *)ref
{
	if (!ref || ([ref refishType] != kGitXRemoteType))
		return NO;

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"remote", @"rm", [ref remoteName], nil];
	NSString * output = [self outputForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the remote: %@\n\n", [ref remoteName]];
		[self.windowController showErrorSheetTitle:@"Delete remote failed!" message:message arguments:arguments output:output];
		return NO;
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

- (BOOL) deleteRef:(PBGitRef *)ref
{
	if (!ref)
		return NO;

	if ([ref refishType] == kGitXRemoteType)
		return [self deleteRemote:ref];

	int retValue = 1;
	NSArray *arguments = [NSArray arrayWithObjects:@"update-ref", @"-d", [ref ref], nil];
	NSString * output = [self outputForArguments:arguments retValue:&retValue];
	if (retValue) {
		NSString *message = [NSString stringWithFormat:@"There was an error deleting the ref: %@\n\n", [ref shortName]];
		[self.windowController showErrorSheetTitle:@"Delete ref failed!" message:message arguments:arguments output:output];
		return NO;
	}

	[self removeBranch:[[PBGitRevSpecifier alloc] initWithRef:ref]];
	PBGitCommit *commit = [self commitForRef:ref];
	[commit removeRef:ref];

	[self reloadRefs];
	return YES;
}


#pragma mark GitX Scripting

- (void)handleRevListArguments:(NSArray *)arguments inWorkingDirectory:(NSURL *)workingDirectory
{
	if (![arguments count])
		return;

	PBGitRevSpecifier *revListSpecifier = nil;

	// the argument may be a branch or tag name but will probably not be the full reference
	if ([arguments count] == 1) {
		PBGitRef *refArgument = [self refForName:[arguments lastObject]];
		if (refArgument) {
			revListSpecifier = [[PBGitRevSpecifier alloc] initWithRef:refArgument];
			revListSpecifier.workingDirectory = workingDirectory;
		}
	}

	if (!revListSpecifier) {
		revListSpecifier = [[PBGitRevSpecifier alloc] initWithParameters:arguments];
		revListSpecifier.workingDirectory = workingDirectory;
	}

	self.currentBranch = [self addBranch:revListSpecifier];
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];
}

- (void)handleBranchFilterEventForFilter:(PBGitXBranchFilterType)filter additionalArguments:(NSMutableArray *)arguments inWorkingDirectory:(NSURL *)workingDirectory
{
	self.currentBranchFilter = filter;
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];

	// treat any additional arguments as a rev-list specifier
	if ([arguments count] > 1) {
		[arguments removeObjectAtIndex:0];
		[self handleRevListArguments:arguments inWorkingDirectory:workingDirectory];
	}
}

- (void)handleGitXScriptingArguments:(NSAppleEventDescriptor *)argumentsList inWorkingDirectory:(NSURL *)workingDirectory
{
	NSMutableArray *arguments = [NSMutableArray array];
	uint argumentsIndex = 1; // AppleEvent list descriptor's are one based
	while(1) {
		NSAppleEventDescriptor *arg = [argumentsList descriptorAtIndex:argumentsIndex++];
		if (arg)
			[arguments addObject:[arg stringValue]];
		else
			break;
	}

	if (![arguments count])
		return;

	NSString *firstArgument = [arguments objectAtIndex:0];

	if ([firstArgument isEqualToString:@"-c"] || [firstArgument isEqualToString:@"--commit"]) {
		[PBGitDefaults setShowStageView:YES];
		[self.windowController showCommitView:self];
		return;
	}

	if ([firstArgument isEqualToString:@"--all"]) {
		[self handleBranchFilterEventForFilter:kGitXAllBranchesFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	if ([firstArgument isEqualToString:@"--local"]) {
		[self handleBranchFilterEventForFilter:kGitXLocalRemoteBranchesFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	if ([firstArgument isEqualToString:@"--branch"]) {
		[self handleBranchFilterEventForFilter:kGitXSelectedBranchFilter additionalArguments:arguments inWorkingDirectory:workingDirectory];
		return;
	}

	// if the argument is not a known command then treat it as a rev-list specifier
	[self handleRevListArguments:arguments inWorkingDirectory:workingDirectory];
}

// see if the current appleEvent has the command line arguments from the gitx cli
// this could be from an openApplication or an openDocument apple event
// when opening a repository this is called before the sidebar controller gets it's awakeFromNib: message
// if the repository is already open then this is also a good place to catch the event as the window is about to be brought forward
- (void)showWindows
{
	NSAppleEventDescriptor *currentAppleEvent = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];

	if (currentAppleEvent) {
		NSAppleEventDescriptor *eventRecord = [currentAppleEvent paramDescriptorForKeyword:keyAEPropData];

		// on app launch there may be many repositories opening, so double check that this is the right repo
		NSString *path = [[eventRecord paramDescriptorForKeyword:typeFileURL] stringValue];
		if (path) {
			NSURL *workingDirectory = [NSURL URLWithString:path];
			if ([[GitRepoFinder gitDirForURL:workingDirectory] isEqual:[self fileURL]]) {
				NSAppleEventDescriptor *argumentsList = [eventRecord paramDescriptorForKeyword:kGitXAEKeyArgumentsList];
				[self handleGitXScriptingArguments:argumentsList inWorkingDirectory:workingDirectory];

				// showWindows may be called more than once during app launch so remove the CLI data after we handle the event
				[currentAppleEvent removeDescriptorWithKeyword:keyAEPropData];
			}
		}
	}

	[super showWindows];
}

// for the scripting bridge
- (void)findInModeScriptCommand:(NSScriptCommand *)command
{
	NSDictionary *arguments = [command arguments];
	NSString *searchString = [arguments objectForKey:kGitXFindSearchStringKey];
	if (searchString) {
		NSInteger mode = [[arguments objectForKey:kGitXFindInModeKey] integerValue];
		[PBGitDefaults setShowStageView:NO];
		[self.windowController showHistoryView:self];
		[self.windowController setHistorySearch:searchString mode:mode];
	}
}


#pragma mark low level

- (int) returnValueForCommand:(NSString *)cmd
{
	int i;
	[self outputForCommand:cmd retValue: &i];
	return i;
}

- (NSFileHandle*) handleForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.gitURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments];
}

- (NSFileHandle*) handleInWorkDirForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.gitURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments inDir:[self workingDirectory]];
}

- (NSFileHandle*) handleForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self handleForArguments:arguments];
}

- (NSString*) outputForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments];
}

- (NSString*) outputForCommand:(NSString *)str retValue:(int *)ret;
{
	NSArray* arguments = [str componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments retValue: ret];
}

- (NSString*) outputForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.fileURL.path];
}

- (NSString*) outputInWorkdirForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: [self workingDirectory]];
}

- (NSString*) outputInWorkdirForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:[self workingDirectory] retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.fileURL.path retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments inputString:(NSString *)input retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:[self workingDirectory]
							inputString:input
							   retValue: ret];
}

- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input byExtendingEnvironment:(NSDictionary *)dict retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:[self workingDirectory]
				 byExtendingEnvironment:dict
							inputString:input
							   retValue: ret];
}

- (BOOL)executeHook:(NSString *)name output:(NSString **)output
{
	return [self executeHook:name withArgs:[NSArray array] output:output];
}

- (BOOL)executeHook:(NSString *)name withArgs:(NSArray *)arguments output:(NSString **)output
{
	NSString *hookPath = [[[[self gitURL] path] stringByAppendingPathComponent:@"hooks"] stringByAppendingPathComponent:name];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:hookPath])
		return TRUE;

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		[self gitURL].path, @"GIT_DIR",
		[[self gitURL].path stringByAppendingPathComponent:@"index"], @"GIT_INDEX_FILE",
		nil
	];

	int ret = 1;
	NSString *_output =	[PBEasyPipe outputForCommand:hookPath withArgs:arguments inDir:[self workingDirectory] byExtendingEnvironment:info inputString:nil retValue:&ret];

	if (output)
		*output = _output;

	return ret == 0;
}

- (NSString *)parseReference:(NSString *)reference
{
	int ret = 1;
	NSString *ref = [self outputForArguments:[NSArray arrayWithObjects: @"rev-parse", @"--verify", reference, nil] retValue: &ret];
	if (ret)
		return nil;

	return ref;
}

- (NSString*) parseSymbolicReference:(NSString*) reference
{
	NSString* ref = [self outputForArguments:[NSArray arrayWithObjects: @"symbolic-ref", @"-q", reference, nil]];
	if ([ref hasPrefix:@"refs/"])
		return ref;

	return nil;
}

- (NSURL*) getIndexURL
{
	NSURL* result = self.gtRepo.index.fileURL;
	return result;
}

-(GTRepository*) gtRepo
{
	if (!_gtRepo)
	{
		NSError* error = nil;
		NSURL* repoURL = [GitRepoFinder gitDirForURL:self.fileURL];
		_gtRepo = [GTRepository repositoryWithURL:repoURL error:&error];
		if (error)
		{
			_gtRepo = nil;
			NSLog(@"Error opening GTRepository for %@\n%@", repoURL, [error userInfo]);
		}
	}
	return _gtRepo;
}

- (void) dealloc
{
	NSLog(@"Dealloc of repository");
	[watcher stop];
}
@end
