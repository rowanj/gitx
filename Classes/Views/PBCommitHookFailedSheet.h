//
//  PBCommitHookFailedSheet.h
//  GitX
//
//  Created by Sebastian Staudt on 9/12/10.
//  Copyright 2010 Sebastian Staudt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PBGitCommitController.h"
#import "PBGitXMessageSheet.h"


@interface PBCommitHookFailedSheet : PBGitXMessageSheet

+ (void)beginWithMessageText:(NSString *)message
					infoText:(NSString *)info
			commitController:(PBGitCommitController *)controller
		   completionHandler:(RJSheetCompletionHandler)handler;

- (IBAction)forceCommit:(id)sender;

@property (nonatomic, strong) PBGitCommitController* commitController;

@end