//
//  PBEasyPipe.h
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PBEasyPipe: NSObject {

}

+ (NSTask *) taskForCommand:(NSString *)cmd withArgs:(NSArray *)args inDir:(NSString *)dir GITX_DEPRECATED;

+ (NSFileHandle*) handleForCommand: (NSString*) cmd withArgs: (NSArray*) args GITX_DEPRECATED;
+ (NSFileHandle*) handleForCommand: (NSString*) cmd withArgs: (NSArray*) args inDir: (NSString*) dir GITX_DEPRECATED;

+ (NSString*) outputForCommand: (NSString*) cmd withArgs: (NSArray*) args GITX_DEPRECATED;
+ (NSString*) outputForCommand: (NSString*) cmd withArgs: (NSArray*) args inDir: (NSString*) dir GITX_DEPRECATED;
+ (NSString*) outputForCommand:(NSString *) cmd
					  withArgs:(NSArray *)  args
						 inDir:(NSString *) dir
				      retValue:(int *)      ret GITX_DEPRECATED;
+ (NSString*) outputForCommand:(NSString *) cmd
					  withArgs:(NSArray *)  args
						 inDir:(NSString *) dir
				   inputString:(NSString *)input
				      retValue:(int *)      ret GITX_DEPRECATED;
+ (NSString*) outputForCommand:(NSString *) cmd
					  withArgs:(NSArray *)  args
						 inDir:(NSString *) dir
		byExtendingEnvironment:(NSDictionary *)dict
				   inputString:(NSString *)input
				      retValue:(int *)      ret GITX_DEPRECATED;


@end
