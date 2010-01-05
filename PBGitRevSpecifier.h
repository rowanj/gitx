//
//  PBGitRevSpecifier.h
//  GitX
//
//  Created by Pieter de Bie on 12-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PBGitRef.h>

@interface PBGitRevSpecifier : NSObject {
	NSString *description;
	NSArray *parameters;
	NSURL *workingDirectory;
}

- (id) initWithParameters:(NSArray*) params;
- (id) initWithRef: (PBGitRef*) ref;

- (BOOL) isSimpleRef;
- (NSString*) simpleRef;
- (BOOL) hasPathLimiter;
- (BOOL) hasLeftRight;

- (BOOL) isEqualTo: (PBGitRevSpecifier*) other;

+ (PBGitRevSpecifier *)allBranchesRevSpec;
+ (PBGitRevSpecifier *)localBranchesRevSpec;

@property(retain)   NSString *description;
@property(readonly) NSArray *parameters;
@property(retain)   NSURL *workingDirectory;

@end
