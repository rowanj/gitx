//
//  RJModalRepoSheet.h
//  GitX
//
//  Created by Rowan James on 1/7/12.
//  Copyright (c) 2012 Phere Development Pty. Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRepository;
@class PBGitWindowController;
@class PBGitRepositoryDocument;

NS_ASSUME_NONNULL_BEGIN

@interface RJModalRepoSheet : NSWindowController

@property (nonnull, strong) PBGitWindowController *windowController;
@property (nonnull, assign) PBGitRepositoryDocument *document;
@property (nonnull, readonly) PBGitRepository *repository;

- (instancetype)initWithWindowNibName:(NSString *)windowNibName windowController:(PBGitWindowController *)windowController;
- (instancetype)initWithWindowNibName:(NSString *)windowNibName;

- (instancetype)init NS_UNAVAILABLE;

typedef void(^RJSheetCompletionHandler)(id sheet, NSModalResponse returnCode);

- (void)beginSheetWithCompletionHandler:(nullable RJSheetCompletionHandler)handler;

/**
 * Temporarily hide the sheet.
 *
 * You must call -show afterward, or the initial completion handler will not be called.
 */
- (void)hide;

/**
 * Dismiss the sheet.
 *
 * This will cause the handler to be called with an NSModalResponseAbort code.
 */
- (void)dismiss;

/**
 * Redisplay a hidden sheet.
 */
- (void)show;

- (IBAction)acceptSheet:(nullable id)sender;
- (IBAction)cancelSheet:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
