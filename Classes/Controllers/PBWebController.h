//
//  PBWebController.h
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface PBWebController : NSObject {
	NSString *startFile;
	BOOL finishedLoading;

	// For async git reading
	NSMapTable *callbacks;

	// For the repository access
	__weak IBOutlet id repository;
}

@property (weak) IBOutlet WebView *view;
@property  NSString *startFile;
@property (weak) id repository;

- (WebScriptObject *) script;
- (void) closeView;
@end
