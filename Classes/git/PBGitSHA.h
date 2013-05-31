//
//  PBGitSHA.h
//  GitX
//
//  Created by BrotherBard on 3/28/10.
//  Copyright 2010 BrotherBard. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <git2/oid.h>


@interface PBGitSHA : NSObject <NSCopying> {
	git_oid oid;
	NSString *string;
}


+ (PBGitSHA *)shaWithOID:(git_oid)oid;
+ (PBGitSHA *)shaWithString:(NSString *)shaString;
+ (PBGitSHA *)shaWithCString:(const char *)shaCString;

- (BOOL)isEqualToOID:(git_oid)other_oid;

@property (readonly) git_oid oid;
@property (readonly) NSString *string;

@end
