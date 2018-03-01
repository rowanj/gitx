//
//  PBRemoteProgressSheetController.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/6/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RJModalRepoSheet.h"

NS_ASSUME_NONNULL_BEGIN

@class PBGitWindowController;

typedef NSError * _Nullable (^PBProgressSheetExecutionHandler)(void);

@interface PBRemoteProgressSheet : RJModalRepoSheet

+ (instancetype)progressSheetWithTitle:(NSString *)title description:(NSString *)description windowController:(PBGitWindowController *)windowController;
+ (instancetype)progressSheetWithTitle:(NSString *)title description:(NSString *)description;

- (void)beginProgressSheetForBlock:(PBProgressSheetExecutionHandler)executionBlock completionHandler:(void (^)(NSError *))completionHandler;

@end

NS_ASSUME_NONNULL_END
