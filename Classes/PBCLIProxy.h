//
//  PBCLIProxy.h
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBCLIProxy : NSObject
{
	NSConnection *connection;
}
@property (retain) NSConnection* connection;
@end

#define ConnectionName @"GitX DO Connection"
#define PBCLIProxyErrorDomain @"PBCLIProxyErrorDomain"

@protocol GitXCliToolProtocol
- (BOOL)openRepository:(NSURL*)repositoryPath arguments: (NSArray*) args error:(NSError**)error;
- (void)openDiffWindowWithDiff:(NSString *)diff;
@end