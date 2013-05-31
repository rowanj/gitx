//
//  PBSourceViewBadge.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/13/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBSourceViewBadge : NSObject {

}

+ (NSImage *) checkedOutBadgeForCell:(NSTextFieldCell *)cell;
+ (NSImage *) numericBadge:(NSInteger)number forCell:(NSTextFieldCell *)cell;

@end
