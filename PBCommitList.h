//
//  PBCommitList.h
//  GitX
//
//  Created by Pieter de Bie on 9/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebView.h>
#import "PBGitHistoryController.h"

@class PBWebHistoryController;

@interface PBCommitList : NSTableView {
	IBOutlet WebView* webView;
	IBOutlet PBWebHistoryController *webController;
	IBOutlet PBGitHistoryController *controller;

	NSPoint mouseDownPoint;
}

@property (readonly) NSPoint mouseDownPoint;
@end
