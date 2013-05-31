//
//  NSOutlineViewExit.m
//  GitX
//
//  Created by Pieter de Bie on 9/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSOutlineViewExt.h"


@implementation NSOutlineView (PBExpandParents)

- (void)PBExpandItem:(id)item expandParents:(BOOL)expand
{
	NSMutableArray *parents = [NSMutableArray array];
	while (item) {
		[parents insertObject:item atIndex:0];
		item = [item parent];
	}
	
	for (id p in parents)
		[self expandItem:p];
}
@end
