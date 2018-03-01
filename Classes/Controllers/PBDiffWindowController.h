//
//  PBDiffWindowController.h
//  GitX
//
//  Created by Pieter de Bie on 13-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitCommit;

@interface PBDiffWindowController : NSWindowController

+ (void)showDiff:(NSString *)diff;
+ (void)showDiffWindowWithFiles:(NSArray *)filePaths fromCommit:(PBGitCommit *)startCommit diffCommit:(PBGitCommit *)diffCommit;
- (instancetype)initWithDiff:(NSString *)diff;

@property (readonly) NSString *diff;
@end
