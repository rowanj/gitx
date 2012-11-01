//
//  PBGitRepository.h
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitHistoryList.h"
#import "PBGitRevSpecifier.h"
#import "PBGitRefish.h"

@class GTRepository;
@class GTConfiguration;

extern NSString* PBGitRepositoryErrorDomain;
typedef enum branchFilterTypes {
	kGitXAllBranchesFilter = 0,
	kGitXLocalRemoteBranchesFilter,
	kGitXSelectedBranchFilter
} PBGitXBranchFilterType;

static NSString * PBStringFromBranchFilterType(PBGitXBranchFilterType type) {
    switch (type) {
        case kGitXAllBranchesFilter:
            return @"All";
            break;
        case kGitXLocalRemoteBranchesFilter:
            return @"Local";
            break;
        case kGitXSelectedBranchFilter:
            return @"Selected";
            break;
        default:
            break;
    }
    return @"Not a branch filter type";
}

@class PBGitWindowController;
@class PBGitCommit;
@class PBGitSHA;
@class PBGitRepositoryWatcher;

@interface PBGitRepository : NSDocument {
	__strong PBGitRepositoryWatcher *watcher;
	__strong PBGitRevSpecifier *_headRef; // Caching
	__strong PBGitSHA* _headSha;
	__strong GTRepository* _gtRepo;
}


@property (assign) BOOL hasChanged;
@property (assign) NSInteger currentBranchFilter;

@property (readonly, strong) PBGitWindowController *windowController;
@property (readonly, getter = getIndexURL) NSURL* indexURL;
@property (readonly, nonatomic) GTConfiguration* configuration;

@property (nonatomic, strong) PBGitHistoryList *revisionList;
@property (nonatomic, strong) NSMutableArray* branches;
@property (nonatomic, strong) PBGitRevSpecifier* currentBranch;
@property (nonatomic, strong) NSMutableDictionary* refs;
@property (readonly, strong) GTRepository* gtRepo;

@property (nonatomic, strong) NSMutableArray* submodules;

- (void) cloneRepositoryToPath:(NSString *)path bare:(BOOL)isBare;
- (void) beginAddRemote:(NSString *)remoteName forURL:(NSString *)remoteURL;
- (void) beginFetchFromRemoteForRef:(PBGitRef *)ref;
- (void) beginPullFromRemote:(PBGitRef *)remoteRef forRef:(PBGitRef *)ref;
- (void) beginPushRef:(PBGitRef *)ref toRemote:(PBGitRef *)remoteRef;
- (BOOL) checkoutRefish:(id <PBGitRefish>)ref;
- (BOOL) checkoutFiles:(NSArray *)files fromRefish:(id <PBGitRefish>)ref;
- (BOOL) mergeWithRefish:(id <PBGitRefish>)ref;
- (BOOL) cherryPickRefish:(id <PBGitRefish>)ref;
- (BOOL) rebaseBranch:(id <PBGitRefish>)branch onRefish:(id <PBGitRefish>)upstream;
- (BOOL) createBranch:(NSString *)branchName atRefish:(id <PBGitRefish>)ref;
- (BOOL) createTag:(NSString *)tagName message:(NSString *)message atRefish:(id <PBGitRefish>)commitSHA;
- (BOOL) deleteRemote:(PBGitRef *)ref;
- (BOOL) deleteRef:(PBGitRef *)ref;

- (NSURL *) gitURL ;

- (NSFileHandle*) handleForCommand:(NSString*) cmd DEPRECATED;
- (NSFileHandle*) handleForArguments:(NSArray*) args DEPRECATED;
- (NSFileHandle *) handleInWorkDirForArguments:(NSArray *)args DEPRECATED;
- (NSString*) outputForCommand:(NSString*) cmd DEPRECATED;
- (NSString *)outputForCommand:(NSString *)str retValue:(int *)ret DEPRECATED;
- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input retValue:(int *)ret DEPRECATED;
- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input byExtendingEnvironment:(NSDictionary *)dict retValue:(int *)ret DEPRECATED;


- (NSString*) outputForArguments:(NSArray*) args DEPRECATED;
- (NSString*) outputForArguments:(NSArray*) args retValue:(int *)ret DEPRECATED;
- (NSString *)outputInWorkdirForArguments:(NSArray*) arguments DEPRECATED;
- (NSString *)outputInWorkdirForArguments:(NSArray*) arguments retValue:(int *)ret DEPRECATED;
- (BOOL)executeHook:(NSString *)name output:(NSString **)output DEPRECATED;
- (BOOL)executeHook:(NSString *)name withArgs:(NSArray*) arguments output:(NSString **)output DEPRECATED;

- (NSString *)workingDirectory;
- (NSString *) projectName;
- (NSString *)gitIgnoreFilename;
- (BOOL)isBareRepository;
+ (BOOL)isBareRepository:(NSURL*)repositoryURL;


- (void) reloadRefs;
- (void) lazyReload;
- (PBGitRevSpecifier*)headRef;
- (PBGitSHA *)headSHA;
- (PBGitCommit *)headCommit;
- (PBGitSHA *)shaForRef:(PBGitRef *)ref;
- (PBGitCommit *)commitForRef:(PBGitRef *)ref;
- (PBGitCommit *)commitForSHA:(PBGitSHA *)sha;
- (BOOL)isOnSameBranch:(PBGitSHA *)baseSHA asSHA:(PBGitSHA *)testSHA;
- (BOOL)isSHAOnHeadBranch:(PBGitSHA *)testSHA;
- (BOOL)isRefOnHeadBranch:(PBGitRef *)testRef;
- (BOOL)checkRefFormat:(NSString *)refName;
- (BOOL)refExists:(PBGitRef *)ref;
- (PBGitRef *)refForName:(NSString *)name;

- (NSArray *) remotes;
- (BOOL) hasRemotes;
- (PBGitRef *) remoteRefForBranch:(PBGitRef *)branch error:(NSError **)error;
- (NSString *) infoForRemote:(NSString *)remoteName;

- (void) readCurrentBranch;
- (PBGitRevSpecifier*) addBranch: (PBGitRevSpecifier*) rev;
- (BOOL)removeBranch:(PBGitRevSpecifier *)rev;

- (NSString*) parseSymbolicReference:(NSString*) ref;
- (NSString*) parseReference:(NSString*) ref;

+ (NSURL*)gitDirForURL:(NSURL*)repositoryURL;
+ (NSURL*)baseDirForURL:(NSURL*)repositoryURL;

- (id) initWithURL: (NSURL*) path;
- (void) setup;
- (void) forceUpdateRevisions;
- (NSURL*) getIndexURL;

// for the scripting bridge
- (void)findInModeScriptCommand:(NSScriptCommand *)command;

@end
