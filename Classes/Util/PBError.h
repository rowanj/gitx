//
//  PBError.h
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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const PBGitXErrorDomain;

@interface NSError (PBError)

/**
 * GitX helper for error creation.
 *
 * @see pb_errorWithDescription:failureReason:underlyingError:userInfo:
 */
+ (NSError *)pb_errorWithDescription:(NSString *)description failureReason:(NSString *)failureReason;

/**
 * GitX helper for error creation, with user info.
 *
 * @see pb_errorWithDescription:failureReason:underlyingError:userInfo:
 */
+ (NSError *)pb_errorWithDescription:(NSString *)description failureReason:(NSString *)failureReason userInfo:(nullable NSDictionary *)userInfo;

/**
 * GitX helper for error creation, with underlying error.
 *
 * @see pb_errorWithDescription:failureReason:underlyingError:userInfo:
 */
+ (NSError *)pb_errorWithDescription:(NSString *)description failureReason:(NSString *)failureReason underlyingError:(nullable NSError *)underError;

/** GitX helper for error creation, with underlying error and user info.
 *
 * This uses a @p 0 error code and the @p PBGitXErrorDomain domain as defaults.
 *
 * @notes
 * The values set as @p description, @p failureReason and @p underlyingError are
 * used in priority over those in the @p userInfo dictionary (if any).
 *
 * @param description     A quick description of the error.
 * @param failureReason   A more verbose explanation.
 * @param underlyingError An error to set as the underlying error.
 * @param userInfo        A dictionary to use as the error userInfo.
 *
 * @return A newly initialized NSError instance.
 */
+ (NSError *)pb_errorWithDescription:(NSString *)description failureReason:(NSString *)failureReason underlyingError:(nullable NSError *)underError userInfo:(nullable NSDictionary *)userInfo;
@end

/** 
 * Easily handle NSError double-pointers.
 *
 * @param error           The error parameter to fill.
 * @param description     A quick description of the error.
 * @param failureReason   A more verbose explanation.
 * @param underlyingError An error to set as the underlying error.
 *
 * @return NO.
 */
BOOL PBReturnError(NSError **error, NSString *description, NSString *failureReason, NSError * __nullable underlyingError);

/**
 * Helper function for easily handling NSError double-pointers.
 *
 * @param error         The error parameter to fill.
 * @param description   A quick description of the error.
 * @param failureReason A more verbose explanation.
 * @param userInfo      A dictionary to use as the error userInfo.
 *
 * @return NO.
 */
BOOL PBReturnErrorWithUserInfo(NSError **error, NSString *description, NSString *failureReason, NSDictionary * _Nullable userInfo);

/**
 * Helper function for easily handling NSError double-pointers.
 *
 * @param error   The error parameter to fill.
 * @param builder A block responsible to create a valid NSError object.
 *
 * @return NO.
 */
BOOL PBReturnErrorWithBuilder(NSError **error, NSError * (^errorBuilder)(void));

NS_ASSUME_NONNULL_END
