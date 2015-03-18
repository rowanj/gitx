//
//  PBQLTextView.h
//  GitX
//
//  Created by Nathan Kinsinger on 3/22/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class PBGitHistoryController;


@interface PBQLTextView : NSTextView {
	__weak IBOutlet PBGitHistoryController *controller;
}

@end
