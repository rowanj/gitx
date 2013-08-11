//
//  PBResetSheet.m
//  GitX
//
//  Created by Leszek Slazynski on 11-03-13.
//  Copyright 2011 LSL. All rights reserved.
//

#import "PBResetSheet.h"
#import "PBGitRefish.h"
#import "PBCommand.h"
#import "PBGitRepository.h"
#import "PBGitWindowController.h"

static const char* StringFromResetType(PBResetType type) {
    static const char* resetTypes[] = {
        "none", "soft", "mixed", "hard", "merge", "keep"
    };
    return resetTypes[type];
}

@implementation PBResetSheet

static PBResetSheet* sheet;

- (void) beginResetSheetForRepository:(PBGitRepository*) repo refish:(id<PBGitRefish>)refish andType:(PBResetType)type {
    defaultType = type;
    targetRefish = refish;
    repository = repo;
    [NSApp beginSheet: [self window]
       modalForWindow: [[repository windowController] window]
        modalDelegate: self
       didEndSelector: nil
          contextInfo: NULL];
}

+ (void) beginResetSheetForRepository:(PBGitRepository*) repo refish:(id<PBGitRefish>)refish andType:(PBResetType)type {
    if (!sheet) {
        sheet = [[self alloc] initWithWindowNibName: @"PBResetSheet"];
    }
    [sheet beginResetSheetForRepository: repo refish: refish andType: type];
}

- (id) init {
    if ( (self = [super initWithWindowNibName: @"PBResetSheet"]) ) {
        defaultType = PBResetTypeMixed;
    }
    return self;
}

- (void) windowDidLoad {
    [resetType setSelectedSegment: defaultType - 1];
    [resetDesc selectTabViewItemAtIndex: defaultType - 1];    
}

- (IBAction)resetBranch:(id)sender {
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];
    PBResetType type = [resetType selectedSegment] + 1;
    
    NSString* type_arg = [NSString stringWithFormat: @"--%s", StringFromResetType(type)];
    NSArray *arguments = [NSArray arrayWithObjects:@"reset", type_arg, [targetRefish refishName], nil];
    PBCommand *cmd = [[PBCommand alloc] initWithDisplayName:@"Reset branch" parameters:arguments repository:repository];
    [cmd invoke];
}

- (IBAction)cancel:(id)sender {
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];
}

@end
