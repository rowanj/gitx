//
//  PBResetSheet.m
//  GitX
//
//  Created by Leszek Slazynski on 11-03-13.
//  Copyright 2011 LSL. All rights reserved.
//

#import "PBResetSheet.h"
#import "PBGitRefish.h"
#import "PBGitRepository.h"
#import "PBGitWindowController.h"
#include "PBGitCommit.h"

#import <ObjectiveGit/ObjectiveGit.h>

@interface PBGitCommit ()
@property (nonatomic, strong, readonly) GTCommit *gtCommit;
@end

static const char* StringFromResetType(GTRepositoryResetType type) {
    switch(type)
    {
        case GTRepositoryResetTypeSoft:
            return "soft";
        case GTRepositoryResetTypeMixed:
            return "mixed";
        case GTRepositoryResetTypeHard:
            return "hard";
    }
}

@implementation PBResetSheet

static PBResetSheet* sheet;

- (void) beginResetSheetForRepository:(PBGitRepository*) repo refish:(id<PBGitRefish>)refish andType:(GTRepositoryResetType)type {
    defaultType = type;
    targetRefish = refish;
    repository = repo;
    [NSApp beginSheet: [self window]
       modalForWindow: [[repository windowController] window]
        modalDelegate: self
       didEndSelector: nil
          contextInfo: NULL];
}

+ (void) beginResetSheetForRepository:(PBGitRepository*) repo refish:(id<PBGitRefish>)refish andType:(GTRepositoryResetType)type {
    if (!sheet) {
        sheet = [[self alloc] initWithWindowNibName: @"PBResetSheet"];
    }
    [sheet beginResetSheetForRepository: repo refish: refish andType: type];
}

- (id) init {
    if ( (self = [super initWithWindowNibName: @"PBResetSheet"]) ) {
        defaultType = GTRepositoryResetTypeMixed;
    }
    return self;
}

- (void) windowDidLoad {
    [resetType setSelectedSegment: defaultType - 1];
    [resetDesc selectTabViewItemAtIndex: defaultType - 1];    
}

- (GTRepositoryResetType) getSelectedResetType {
    NSInteger selectedSegment = [resetType selectedSegment];

    switch (selectedSegment) {
        case 0:
            return GTRepositoryResetTypeSoft;
        case 1:
            return GTRepositoryResetTypeMixed;
        case 2:
            return GTRepositoryResetTypeHard;
        default:
            NSAssert1(false, @"unknown reset method: %ld", selectedSegment);
            return -1;
    }
}

- (IBAction)resetBranch:(id)sender {
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];
    GTRepositoryResetType type = [self getSelectedResetType];

    //TODO: show alert and then reset the branch
    NSInteger alertRet = [[NSAlert alertWithMessageText:@"Reset"
                                defaultButton:nil
                              alternateButton:@"Cancel"
                                  otherButton:nil
                    informativeTextWithFormat:@"Are you sure you want to perform a %s reset to %@?",
                           StringFromResetType(type),
                           [targetRefish refishName]]
					runModal];
    
    if(alertRet == NSAlertDefaultReturn)
    {
        GTRepository* repo = self->repository.gtRepo;
        PBGitCommit* commit;

        //test if we already have a commit
        //if not, resolve to a commit
        //this is somewhat ugly, so maybe this can be replaced with better code
        if([targetRefish refishType] == kGitXCommitType)
        {
            commit = targetRefish;
        }
        else
        {
            commit = [self->repository commitForRef:targetRefish];
        }

        NSAssert1(commit != nil, @"could not resolve commit for %@", [targetRefish refishName]);
        BOOL success = [repo resetToCommit:commit.gtCommit withResetType:type error:NULL];

        NSAssert(success, @"reset was not successful");

        [self->repository reloadRefs];
    }
}

- (IBAction)cancel:(id)sender {
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];
}

@end
