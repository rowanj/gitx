//
//  PBCreateTagSheet.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/18/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PBGitRefish.h"
#import "RJModalRepoSheet.h"

@class PBGitRepository;


@interface PBCreateTagSheet : RJModalRepoSheet

+ (void) beginSheetWithRefish:(id <PBGitRefish>)refish windowController:(PBGitWindowController *)windowController completionHandler:(RJSheetCompletionHandler)handler;

- (IBAction) createTag:(id)sender;
- (IBAction) closeCreateTagSheet:(id)sender;

@property (nonatomic, strong) id <PBGitRefish> targetRefish;

@property (nonatomic, weak) IBOutlet NSTextField *tagNameField;
@property (nonatomic, strong) IBOutlet NSTextView  *tagMessageText;
@property (nonatomic, weak) IBOutlet NSTextField *errorMessageField;

@end
