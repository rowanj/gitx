//
//  PBServicesController.h
//  GitX
//
//  Created by Pieter de Bie on 10/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBServicesController : NSObject

- (void)completeSha:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

@end
