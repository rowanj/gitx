//
//  PBGitSVSubmoduleItem.m
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import "PBGitSVSubmoduleItem.h"

@implementation PBGitSVSubmoduleItem

+ (id) itemWithSubmodule:(PBGitSubmodule*)submodule
{
    PBGitSVSubmoduleItem* item = [[self alloc] init];
    [item setSubmodule:submodule];
    [item setTitle:submodule.name];
    return item;
}
@end
