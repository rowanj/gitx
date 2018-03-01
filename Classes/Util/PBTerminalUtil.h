//
//  PBTerminalUtil.h
//  GitX
//
//  Created by Sven on 07.08.16.
//
//

#import <Foundation/Foundation.h>

@interface PBTerminalUtil : NSObject

/*
 * Runs the given command in OS X’s Terminal.app
 * at the given directory.
 */
+ (void) runCommand:(NSString *)command inDirectory:(NSURL *)directory;

@end
