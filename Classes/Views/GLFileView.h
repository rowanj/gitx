//
//  GLFileView.h
//  GitX
//
//  Created by German Laullon on 14/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MGScopeBar/MGScopeBarDelegateProtocol.h>

#import "PBWebController.h"

@class PBGitHistoryController;

@interface GLFileView : PBWebController <MGScopeBarDelegate> {
	IBOutlet __unsafe_unretained PBGitHistoryController* historyController;
	IBOutlet __weak MGScopeBar *typeBar;
	NSMutableArray *groups;
	NSString *logFormat;
	IBOutlet __weak NSView *accessoryView;
	IBOutlet __weak NSSplitView *fileListSplitView;
}

- (void)showFile;
- (void)didLoad;
- (NSString *)parseBlame:(NSString *)txt;
- (NSString *)parseHTML:(NSString *)txt;

@property NSMutableArray *groups;
@property NSString *logFormat;

@end
