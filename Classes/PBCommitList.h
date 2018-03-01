//
//  PBCommitList.h
//  GitX
//
//  Created by Pieter de Bie on 9/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebView.h>

@class PBGitHistoryController;
@class PBWebHistoryController;
@class PBHistorySearchController;

typedef void(^PBFindPanelActionBlock)(id sender);

@interface PBCommitList : NSTableView {
	__weak IBOutlet WebView* webView;
	__weak IBOutlet PBWebHistoryController *webController;
	__weak IBOutlet PBGitHistoryController *controller;
	__weak IBOutlet PBHistorySearchController *searchController;

    BOOL useAdjustScroll;
	NSPoint mouseDownPoint;
}

@property (readonly) NSPoint mouseDownPoint;
@property (assign) BOOL useAdjustScroll;
@property (copy) PBFindPanelActionBlock findPanelActionBlock;

@end
