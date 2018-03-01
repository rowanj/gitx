//
//  PBUnsortableTableHeader.h
//  GitX
//
//  Created by Pieter de Bie on 03-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBUnsortableTableHeader : NSTableHeaderView {
	IBOutlet NSArrayController *controller;
	int clickCount;
	NSInteger columnIndex;
}

@end
