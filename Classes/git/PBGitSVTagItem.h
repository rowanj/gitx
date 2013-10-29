//
//  PBGitSVTagItem.h
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"

@interface PBGitSVTagItem : PBSourceViewItem {

}

+ (id)tagItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier;

@end
