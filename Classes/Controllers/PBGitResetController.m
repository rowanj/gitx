//
//  PBGitResetController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitResetController.h"
#import "PBGitRepository.h"
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
    [self resetToRefish: [PBGitRef refFromString: @"HEAD"] type: GTRepositoryResetTypeMixed];
}

- (void) resetToRefish:(id<PBGitRefish>) refish type:(GTRepositoryResetType)type {
    [PBResetSheet beginResetSheetForRepository: repository refish: refish andType: type];
}

@end
