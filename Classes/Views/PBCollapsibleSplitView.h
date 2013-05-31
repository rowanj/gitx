//
//  PBCollapsibleSplitView.h
//  GitX
//
//  This is a limited subclass of a SplitView. It adds methods to aid in
//  collapsing/uncollapsing subviews using the mouse or programmatically.
//  Right now it only works for vertical layouts and with two subviews.
//
//  Created by Johannes Gilger on 6/21/09.
//  Copyright 2009 Johannes Gilger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBNiceSplitView.h"

@interface PBCollapsibleSplitView : PBNiceSplitView {
	CGFloat topViewMin;
	CGFloat bottomViewMin;
	CGFloat splitterPosition;
}

@property (readonly) CGFloat topViewMin;
@property (readonly) CGFloat bottomViewMin;

- (void)setTopMin:(CGFloat)topMin andBottomMin:(CGFloat)bottomMin;
- (void)uncollapse;
- (void)keyDown:(NSEvent *)event;

@end
