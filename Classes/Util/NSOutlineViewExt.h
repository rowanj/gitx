//
//  NSOutlineViewExit.h
//  GitX
//
//  Created by Pieter de Bie on 9/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSOutlineView (PBExpandParents) 

- (void)PBExpandItem:(id)item expandParents:(BOOL)expand;
@end
