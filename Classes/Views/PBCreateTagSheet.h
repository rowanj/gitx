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
{
}

+ (void) beginCreateTagSheetAtRefish:(id <PBGitRefish>)refish inRepository:(PBGitRepository *)repo;

- (IBAction) createTag:(id)sender;
- (IBAction) closeCreateTagSheet:(id)sender;

@property (nonatomic, strong) id <PBGitRefish> targetRefish;

@property (nonatomic, dct_weak) IBOutlet NSTextField *tagNameField;
@property (nonatomic, dct_weak) IBOutlet NSTextView  *tagMessageText;
@property (nonatomic, dct_weak) IBOutlet NSTextField *errorMessageField;

@end
