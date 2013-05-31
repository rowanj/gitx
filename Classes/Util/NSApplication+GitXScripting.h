//
//  NSApplication+GitXScripting.h
//  GitX
//
//  Created by Nathan Kinsinger on 8/15/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSApplication (GitXScripting)

- (void)showDiffScriptCommand:(NSScriptCommand *)command;
- (void)initRepositoryScriptCommand:(NSScriptCommand *)command;
- (void)cloneRepositoryScriptCommand:(NSScriptCommand *)command;

@end
