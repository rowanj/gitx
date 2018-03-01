//
//  PBSourceViewStash.m
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import "PBGitSVStashItem.h"
#import "PBGitRevSpecifier.h"


@implementation PBGitSVStashItem

+ (id)itemWithStash:(PBGitStash *)stash
{
    NSString * title = [NSString stringWithFormat:@"@{%zd}: %@", stash.index, stash.message];
    PBGitSVStashItem * item = [self itemWithTitle:title];
    item.stash = stash;
    item.revSpecifier = [[PBGitRevSpecifier alloc] initWithRef:stash.ref];
    return item;
}

-(PBGitRef *)ref {
    return self.stash.ref;
}

@end
