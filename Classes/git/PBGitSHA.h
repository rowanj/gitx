//
//  PBGitSHA.h
//  GitX
//
//  Created by BrotherBard on 3/28/10.
//  Copyright 2010 BrotherBard. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PBGitSHA : NSObject <NSCopying>

+ (PBGitSHA *)shaWithOID:(git_oid const *)oid;
+ (PBGitSHA *)shaWithString:(NSString *)shaString;
+ (PBGitSHA *)shaWithCString:(const char *)shaCString;

- (BOOL)isEqualToOID:(git_oid const *)other_oid;

@property (nonatomic, assign, readonly) git_oid oid;
@property (nonatomic, strong, readonly) NSString *string;

@end
