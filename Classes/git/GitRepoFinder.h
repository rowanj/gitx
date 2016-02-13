//
//  GitRepoFinder.h
//  GitX
//
//  Created by Rowan James on 13/11/2012.
//
//

#import <Foundation/Foundation.h>

@interface GitRepoFinder : NSObject

+ (NSURL*)workDirForURL:(NSURL*)fileURL;
+ (NSURL*)gitDirForURL:(NSURL*)fileURL;

@end
