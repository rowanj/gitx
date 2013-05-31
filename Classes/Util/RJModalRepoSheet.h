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

@interface RJModalRepoSheet : NSWindowController

@property (nonatomic, strong) PBGitRepository* repository;
@property (nonatomic, strong) PBGitWindowController* repoWindow;

- (id) initWithWindowNibName:(NSString *)windowNibName forRepo:(PBGitRepository*)repo;

- (void) show;
- (void) hide;

@end
