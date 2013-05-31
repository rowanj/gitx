//
//  PBWebDiffController.h
//  GitX
//
//  Created by Pieter de Bie on 13-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBWebController.h"
#import "PBDiffWindowController.h"

@interface PBWebDiffController : PBWebController {
	IBOutlet PBDiffWindowController *diffController;
}

- (void) showDiff:(NSString *)diff;
@end
