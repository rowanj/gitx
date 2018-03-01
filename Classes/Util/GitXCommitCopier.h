//
//  GitXCommitCopier.h
//  GitX
//
//  Created by Sven-S. Porst on 20.12.15.
//
//

#import <Foundation/Foundation.h>

@class PBGitCommit;


@interface GitXCommitCopier : NSValueTransformer

+ (NSString * _Nonnull) toFullSHA:(NSArray<PBGitCommit *> * _Nonnull)commits;
+ (NSString * _Nonnull) toShortName:(NSArray<PBGitCommit *> * _Nonnull)commits;
+ (NSString * _Nonnull) toSHAAndHeadingString:(NSArray<PBGitCommit *> * _Nonnull)commits;
+ (NSString * _Nonnull) toPatch:(NSArray<PBGitCommit *> * _Nonnull)commits;

+ (void) putStringToPasteboard:(NSString * _Nullable)string;

@end
