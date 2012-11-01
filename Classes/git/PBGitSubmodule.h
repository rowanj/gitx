//
//  PBGitSubmodule.h
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import <Foundation/Foundation.h>


@interface PBGitSubmodule : NSObject
@property (nonatomic, assign) git_submodule* submodule;
- (NSString*) path;
- (NSString*) name;
@property (nonatomic, strong) NSString* workingDirectory;
@end
