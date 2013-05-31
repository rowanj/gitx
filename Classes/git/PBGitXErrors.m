//
//  PBGitXErrors.m
//  GitX
//
//  Created by Andre Berg on 31.10.09.
//  Copyright 2009 Berg Media. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//    http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "PBGitXErrors.h"

NSString * const PBGitXErrorDomain      = @"PBGitXErrorDomain";
NSString * const PBCLIProxyErrorDomain  = @"PBCLIProxyErrorDomain";
NSString * const PBGitRepositoryErrorDomain  = @"PBGitRepositoryErrorDomain";

NSString * const PBInvalidBranchErrorMessage  = @"Please select a local branch from the branch popup menu, which has a corresponding remote tracking branch set up.\n\n"
                                                @"You can also use the context menu to choose a branch by right clicking on its label in the history view.";

NSString * const PBMissingRemoteErrorMessage  = @"This branch does not appear to have a remote tracking branch associated in its config file section.";

const NSInteger PBNotAGitRepositoryErrorCode            = 1;
const NSInteger PBFileReadingUnsupportedErrorCode       = 2;
const NSInteger PBGitBinaryNotFoundErrorCode            = 3;
const NSInteger PBNotAValidRefFormatErrorCode           = 4;
// const NSInteger PBCLINilValueForArgumentsCode           = 5;
// const NSInteger PBCLINilValueForRepositoryPathErrorCode = 6;
