//
//  PBGitResetController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitResetController.h"
#import "PBGitRepository.h"
#import "PBCommand.h"
#import "PBGitRefish.h"
#import "PBResetSheet.h"


@implementation PBGitResetController

- (id) initWithRepository:(PBGitRepository *) repo {
	if ((self = [super init])){
        repository = repo;
    }
    return self;
}

- (void) resetHardToHead {
    [self resetToRefish: [PBGitRef refFromString: @"HEAD"] type: PBResetTypeHard];
}

- (void) resetToRefish:(id<PBGitRefish>) refish type:(PBResetType)type {
    [PBResetSheet beginResetSheetForRepository: repository refish: refish andType: type];
}

- (void) reset {
	//TODO missing implementation
}

- (NSArray *) menuItems {
	NSMenuItem *resetHeadHardly = [[NSMenuItem alloc] initWithTitle:@"Reset hard to HEAD" action:@selector(resetHardToHead) keyEquivalent:@""];
	[resetHeadHardly setTarget:self];
	
	NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"Reset..." action:@selector(reset) keyEquivalent:@""];
	[reset setTarget:self];
	
	return [NSArray arrayWithObjects:resetHeadHardly, reset, nil];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem {
	BOOL shouldBeEnabled = YES;
	SEL action = [menuItem action];
	if (action == @selector(reset)) {
		shouldBeEnabled = NO;
		//TODO missing implementation
	}
	return shouldBeEnabled;
}


@end
