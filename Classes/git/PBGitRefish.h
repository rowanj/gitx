//
//  PBGitRefish.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/25/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//  Several git commands can take a ref "refs/heads/master" or an SHA.
//  Use <PBGitRefish> to accept a PBGitRef or a PBGitCommit without having to write
//  two separate methods.
//
//  refishName  the full name of the ref "refs/heads/master" or the full SHA
//              used in git commands
//  shortName   a more user friendly version of the refName, "master" or a short SHA
//  refishType  a short name for the type

@protocol PBGitRefish <NSObject>

- (NSString *) refishName;
- (NSString *) shortName;
- (NSString *) refishType;

@end
