//
//  PBSourceViewStash.h
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"
#import "PBGitStash.h"

@interface PBGitSVStashItem : PBSourceViewItem

+ (id) itemWithStash:(PBGitStash*)stash;

@property (nonatomic, strong) PBGitStash* stash;

@end
