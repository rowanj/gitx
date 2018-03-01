//
//  PBRepositoryFinder.h
//  GitX
//
//  Created by Rowan James on 13/11/2012.
//
//

#import <Foundation/Foundation.h>

@interface PBRepositoryFinder : NSObject

+ (NSURL *)fileURLForURL:(NSURL *)inputURL;
+ (NSURL*)workDirForURL:(NSURL*)fileURL;
+ (NSURL*)gitDirForURL:(NSURL*)fileURL;

@end
