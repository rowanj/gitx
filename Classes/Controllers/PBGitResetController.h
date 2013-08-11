//
//  PBGitResetController.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "PBResetSheet.h"

@class PBGitRepository;
@protocol PBGitRefish;

@interface PBGitResetController : NSObject {
	__unsafe_unretained PBGitRepository *repository;
}
- (id) initWithRepository:(PBGitRepository *) repo;

// actions
- (void) resetToRefish: (id<PBGitRefish>) spec type: (GTRepositoryResetType) type;
- (void) resetHardToHead;

@end
