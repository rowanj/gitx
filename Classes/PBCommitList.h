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
	IBOutlet __weak WebView* webView;
	IBOutlet __weak PBWebHistoryController *webController;
	IBOutlet __unsafe_unretained PBGitHistoryController *controller;
	IBOutlet __weak PBHistorySearchController *searchController;

    BOOL useAdjustScroll;
	NSPoint mouseDownPoint;
}

@property (readonly) NSPoint mouseDownPoint;
@property (assign) BOOL useAdjustScroll;
@end
