//
//  PBOpenShallowRepositoryErrorRecoveryAttempter.h
//  GitX
//
//  Created by  Sven on 07.08.16.
//
//

#import <Foundation/Foundation.h>

@interface PBOpenShallowRepositoryErrorRecoveryAttempter : NSObject

- (instancetype) initWithURL:(NSURL *)url;

+ (NSArray<NSString*>*) errorDialogButtonNames;

@end