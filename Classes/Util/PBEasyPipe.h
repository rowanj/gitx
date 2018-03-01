//
//  PBEasyPipe.h
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PBEasyPipe: NSObject

/* The following methods are kept for backward-compatibility.
 * Newly-written code should use the block-based methods above.
 */
+ (NSTask *)taskForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir GITX_DEPRECATED;
+ (NSString *)outputForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args GITX_DEPRECATED;
+ (NSString *)outputForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir GITX_DEPRECATED;
+ (NSString *)outputForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir retValue:(nullable int *)ret GITX_DEPRECATED;
+ (NSString *)outputForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir inputString:(nullable NSString *)input retValue:(nullable int *)ret GITX_DEPRECATED;
+ (NSString *)outputForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir byExtendingEnvironment:(nullable NSDictionary *)dict inputString:(nullable NSString *)input retValue:(nullable int *)ret GITX_DEPRECATED;

/*
 * The following methods are deprecated because they're inherently racy:
 * They are launched at the end of the method, but you might not be able to
 * register for the NSFileHandle notification before they are done running.
 */
+ (NSFileHandle *)handleForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args GITX_DEPRECATED;
+ (NSFileHandle *)handleForCommand:(NSString *)cmd withArgs:(nullable NSArray *)args inDir:(nullable NSString *)dir GITX_DEPRECATED;

@end

NS_ASSUME_NONNULL_END