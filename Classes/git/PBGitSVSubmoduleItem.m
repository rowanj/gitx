//
//  PBGitSVSubmoduleItem.m
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import "PBGitSVSubmoduleItem.h"

@implementation PBGitSVSubmoduleItem

+ (id) itemWithSubmodule:(GTSubmodule*)submodule
{
    PBGitSVSubmoduleItem* item = [[self alloc] init];
	item.submodule = submodule;
    return item;
}

- (NSString *)title
{
	return self.submodule.name;
}

- (NSURL *)path
{
	NSURL *parentURL = self.submodule.parentRepository.fileURL;
	NSURL *result = [parentURL URLByAppendingPathComponent:self.submodule.path];
	return result;
}
@end
