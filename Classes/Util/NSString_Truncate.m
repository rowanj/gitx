//
//  NSString_Truncate.m
//  GitX
//
//  Created by Andre Berg on 24.03.10.
//  Copyright 2010 Berg Media. All rights reserved.
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

#import "NSString_Truncate.h"

@implementation NSString (PBGitXTruncateExtensions)

- (NSString *) truncateToLength:(NSUInteger)targetLength mode:(PBNSStringTruncateMode)mode indicator:(NSString *)indicatorString {
    
    NSString * res = nil;
    NSString * firstPart;
    NSString * lastPart;
    
    if (!indicatorString) {
        indicatorString = @"...";
    }
    
    NSUInteger stringLength = [self length];
    NSUInteger ilength = [indicatorString length];
    
    if (stringLength <= targetLength) {
        return self;
    } else if (stringLength <= 0 || (!self)) {
        return nil;
    } else {
        switch (mode) {
            case PBNSStringTruncateModeCenter:
                firstPart = [self substringToIndex:(targetLength/2)];
                lastPart = [self substringFromIndex:(stringLength-((targetLength/2))+ilength)];
                res = [NSString stringWithFormat:@"%@%@%@", firstPart, indicatorString, lastPart];                
                break;
            case PBNSStringTruncateModeStart:
                res = [NSString stringWithFormat:@"%@%@", indicatorString, [self substringFromIndex:((stringLength-targetLength)+ilength)]];
                break;
            case PBNSStringTruncateModeEnd:
                res = [NSString stringWithFormat:@"%@%@", [self substringToIndex:(targetLength-ilength)], indicatorString];
                break;
            default:
                ;
                NSException * myException = [NSException exceptionWithName:NSInvalidArgumentException 
                                                                    reason:[NSString stringWithFormat:
                                                                            @"[%@ %@] called with nonsensical value for 'mode' (mode = %d) ***",
                                                                            [self class], NSStringFromSelector(_cmd), mode]
                                                                  userInfo:nil];
                @throw myException;
                return res;
                break;
        };
    }
    return res;
}

@end
