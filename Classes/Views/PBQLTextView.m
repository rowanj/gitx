//
//  PBQLTextView.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/22/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBQLTextView.h"
#import "PBGitHistoryController.h"


@implementation PBQLTextView

- (void) keyDown: (NSEvent *) event
{
	if ([[event characters] isEqualToString:@" "]) {
		[controller toggleQLPreviewPanel:self];
		return;
	}
	
	[super keyDown:event];
}

@end
