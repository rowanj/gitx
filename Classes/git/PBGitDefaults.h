//
//  PBGitDefaults.h
//  GitX
//
//  Created by Jeff Mesnil on 19/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

@interface PBGitDefaults : NSObject
{

}

+ (int) commitMessageViewVerticalLineLength;
+ (int) commitMessageViewVerticalBodyLineLength;
+ (BOOL) commitMessageViewHasVerticalLine;
+ (BOOL) isGistEnabled;
+ (BOOL) isGravatarEnabled;
+ (BOOL) confirmPublicGists;
+ (BOOL) isGistPublic;
+ (BOOL)showWhitespaceDifferences;
+ (BOOL) shouldCheckoutBranch;
+ (void) setShouldCheckoutBranch:(BOOL)shouldCheckout;
+ (NSString *) recentCloneDestination;
+ (void) setRecentCloneDestination:(NSString *)path;
+ (BOOL) showStageView;
+ (void) setShowStageView:(BOOL)suppress;
+ (NSInteger) branchFilter;
+ (void) setBranchFilter:(NSInteger)state;
+ (NSInteger)historySearchMode;
+ (void)setHistorySearchMode:(NSInteger)mode;
+ (BOOL)useRepositoryWatcher;


// Suppressed Dialog Warnings
+ (void)suppressDialogWarningForDialog:(NSString *)dialog;
+ (BOOL)isDialogWarningSuppressedForDialog:(NSString *)dialog;
+ (void)resetAllDialogWarnings;

@end
