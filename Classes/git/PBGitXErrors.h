//
//  PBGitXErrors.h
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

#import <Cocoa/Cocoa.h>

extern NSString * const PBGitXErrorDomain;
extern NSString * const PBCLIProxyErrorDomain;
extern NSString * const PBGitRepositoryErrorDomain;

extern NSString * const PBInvalidBranchErrorMessage;
extern NSString * const PBMissingRemoteErrorMessage;

extern const NSInteger PBFileReadingUnsupportedErrorCode;           /* @"Reading files is not supported." */
extern const NSInteger PBNotAGitRepositoryErrorCode;                /* @"%@ does not appear to be a git repository." */
extern const NSInteger PBGitBinaryNotFoundErrorCode;
extern const NSInteger PBNotAValidRefFormatErrorCode;               /* happens when check-ref-format in PBGitRepository -checkRefFormat returns NO */
// extern const NSInteger PBCLINilValueForArgumentsCode;               /* PBCLIProxy -openRepository:arguments:error: is passed nil for arguments */
// extern const NSInteger PBCLINilValueForRepositoryPathErrorCode;     /* PBCLIProxy -openRepository:arguments:error: is passed nil for repositoryPath */