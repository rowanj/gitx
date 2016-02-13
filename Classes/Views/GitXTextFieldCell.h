//
//  GitXTextFieldCell.h
//  GitX
//
//  Created by Nathan Kinsinger on 8/27/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PBRefContextDelegate;

@interface GitXTextFieldCell : NSTextFieldCell {
	IBOutlet id<PBRefContextDelegate> contextMenuDelegate;
}

@end
