//
//  PBCreateBranchSheet.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/13/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RJModalRepoSheet.h"

@protocol PBGitRefish;
@class PBGitRef;
@class PBGitRepositoryDocument;

NS_ASSUME_NONNULL_BEGIN

@interface PBCreateBranchSheet : RJModalRepoSheet

+ (void)beginSheetWithRefish:(id <PBGitRefish>)ref windowController:(PBGitWindowController *)windowController completionHandler:(nullable RJSheetCompletionHandler)handler;

- (IBAction) createBranch:(nullable id)sender;
- (IBAction) closeCreateBranchSheet:(nullable id)sender;

@property (nonatomic, strong) id <PBGitRefish> startRefish;
@property (nonatomic, strong) PBGitRef *selectedRef;
@property (nonatomic, assign) BOOL shouldCheckoutBranch;

@property (nonatomic, assign) IBOutlet NSTextField *branchNameField;
@property (nonatomic, assign) IBOutlet NSTextField *errorMessageField;

@end

NS_ASSUME_NONNULL_END
