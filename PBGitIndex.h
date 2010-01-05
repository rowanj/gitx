//
//  PBGitIndex.h
//  GitX
//
//  Created by Pieter de Bie on 9/12/09.
//  Copyright 2009 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRepository;
@class PBChangedFile;

/*
 * Notifications this class will send
 */

// Refreshing index
extern NSString *PBGitIndexIndexRefreshStatus;
extern NSString *PBGitIndexIndexRefreshFailed;
extern NSString *PBGitIndexFinishedIndexRefresh;

// The "indexChanges" array has changed
extern NSString *PBGitIndexIndexUpdated;

// Committing files
extern NSString *PBGitIndexCommitStatus;
extern NSString *PBGitIndexCommitFailed;
extern NSString *PBGitIndexFinishedCommit;

// Changing to amend
extern NSString *PBGitIndexAmendMessageAvailable;

// This is for general operations, like applying a patch
extern NSString *PBGitIndexOperationFailed;



// Represents a git index for a given work tree.
// As a single git repository can have multiple trees,
// the tree has to be given explicitly, even though
// multiple trees is not yet supported in GitX
@interface PBGitIndex : NSObject {
	
@private
	PBGitRepository *repository;
	NSURL *workingDirectory;
	NSMutableArray *files;

	NSUInteger refreshStatus;
	NSDictionary *amendEnvironment;
	BOOL amend;
}

// Whether we want the changes for amending,
// or for
@property BOOL amend;

- (id)initWithRepository:(PBGitRepository *)repository workingDirectory:(NSURL *)workingDirectory;

// A list of PBChangedFile's with differences between the work tree and the index
// This method is KVO-aware, so changes when any of the index-modifying methods are called
// (including -refresh)
- (NSArray *)indexChanges;

// Refresh the index
- (void)refresh;

- (void)commitWithMessage:(NSString *)commitMessage;

// Inter-file changes:
- (BOOL)stageFiles:(NSArray *)stageFiles;
- (BOOL)unstageFiles:(NSArray *)unstageFiles;
- (void)discardChangesForFiles:(NSArray *)discardFiles;

// Intra-file changes
- (BOOL)applyPatch:(NSString *)hunk stage:(BOOL)stage reverse:(BOOL)reverse;
- (NSString *)diffForFile:(PBChangedFile *)file staged:(BOOL)staged contextLines:(NSUInteger)context;

@end
