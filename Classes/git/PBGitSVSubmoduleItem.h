//
//  PBGitSVSubmoduleItem.h
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import <Foundation/Foundation.h>
#import "PBSourceViewItem.h"


@interface PBGitSVSubmoduleItem : PBSourceViewItem
+ (id) itemWithSubmodule:(GTSubmodule*)submodule;
@property (nonatomic, strong) GTSubmodule* submodule;
@property (nonatomic, readonly) NSURL *path;
@end
