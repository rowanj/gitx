//
//  PBSourceViewAction.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"

@interface PBSourceViewAction : PBSourceViewItem {
	NSImage *icon;
}

@property(retain) NSImage *icon;
@end
