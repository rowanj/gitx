//
//  PBGitRevisionCell.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevisionCell.h"
#import "PBGitRef.h"
#import "RoundedRectangle.h"

@implementation PBGitRevisionCell


- (id) initWithCoder: (id) coder
{
	self = [super initWithCoder:coder];
	textCell = [[NSTextFieldCell alloc] initWithCoder:coder];
	return self;
}

- (NSArray*) colors
{
	return 	[NSArray arrayWithObjects:
				[NSColor colorWithCalibratedRed: 0X4e/256.0 green:0X9A/256.0 blue: 0X06/256.0 alpha: 1.0],
				[NSColor colorWithCalibratedRed: 0X20/256.0 green:0X4A/256.0 blue: 0X87/256.0 alpha: 1.0],
				[NSColor colorWithCalibratedRed: 0XC4/256.0 green:0XA0/256.0 blue: 0 alpha: 1.0],
				[NSColor colorWithCalibratedRed: 0X5C/256.0 green:0X35/256.0 blue: 0X66/256.0 alpha: 1.0],
				[NSColor colorWithCalibratedRed: 0XA4/256.0 green:0X00/256.0 blue: 0X00/256.0 alpha: 1.0],
				[NSColor colorWithCalibratedRed: 0XCE/256.0 green:0X5C/256.0 blue: 0 alpha: 1.0],
				nil];
}

- (void) drawLineFromColumn: (int) from toColumn: (int) to inRect: (NSRect) r offset: (int) offset color: (int) c
{

	int columnWidth = 10;
	NSPoint origin = r.origin;
	
	NSPoint source = NSMakePoint(origin.x + columnWidth* from, origin.y + offset);
	NSPoint center = NSMakePoint( origin.x + columnWidth * to, origin.y + r.size.height * 0.5 + 0.5);

	// Just use red for now.
	NSArray* colors = [self colors];
	[[colors objectAtIndex: c % [colors count]] set];
	
	NSBezierPath * path = [NSBezierPath bezierPath];
	[path setLineWidth:2];
	
	[path moveToPoint: source];
	[path lineToPoint: center];
	[path stroke];
	
}

- (void) drawCircleInRect: (NSRect) r
{

	int c = cellInfo.position;
	int columnWidth = 10;
	NSPoint origin = r.origin;
	NSPoint columnOrigin = { origin.x + columnWidth * c, origin.y};

	NSRect oval = { columnOrigin.x - 5, columnOrigin.y + r.size.height * 0.5 - 5, 10, 10};

	
	NSBezierPath * path = [NSBezierPath bezierPathWithOvalInRect:oval];

	[[NSColor blackColor] set];
	[path fill];
	
	NSRect smallOval = { columnOrigin.x - 3, columnOrigin.y + r.size.height * 0.5 - 3, 6, 6};
	[[NSColor whiteColor] set];
	path = [NSBezierPath bezierPathWithOvalInRect:smallOval];
	[path fill];	
}

- (void) drawTriangleInRect: (NSRect) r sign: (char) sign
{
	int c = cellInfo.position;
	int columnHeight = 10;
	int columnWidth = 8;

	NSPoint top;
	if (sign == '<')
		top.x = round(r.origin.x) + 10 * c + 4;
	else {
		top.x = round(r.origin.x) + 10 * c - 4;
		columnWidth *= -1;
	}
	top.y = r.origin.y + (r.size.height - columnHeight) / 2;

	NSBezierPath * path = [NSBezierPath bezierPath];
	// Start at top
	[path moveToPoint: NSMakePoint(top.x, top.y)];
	// Go down
	[path lineToPoint: NSMakePoint(top.x, top.y + columnHeight)];
	// Go left top
	[path lineToPoint: NSMakePoint(top.x - columnWidth, top.y + columnHeight / 2)];
	// Go to top again
	[path closePath];

	[[NSColor whiteColor] set];
	[path fill];
	[[NSColor blackColor] set];
	[path setLineWidth: 2];
	[path stroke];
}

- (NSMutableDictionary*) attributesForRefLabelSelected: (BOOL) selected
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] initWithCapacity:2] autorelease];
	NSMutableParagraphStyle* style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	
	[style setAlignment:NSCenterTextAlignment];
	[attributes setObject:style forKey:NSParagraphStyleAttributeName];
	[attributes setObject:[NSFont fontWithName:@"Helvetica" size:9] forKey:NSFontAttributeName];

	//if (selected)
	//	[attributes setObject:[NSColor alternateSelectedControlTextColor] forKey:NSForegroundColorAttributeName];

	return attributes;
}

- (NSColor*) colorForRef: (PBGitRef*) ref
{
	BOOL isHEAD = [ref.ref isEqualToString:[[[controller repository] headRef] simpleRef]];

	if (isHEAD)
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xa6/256.0 blue: 0X4f/256.0 alpha: 1.0];

	NSString* type = [ref type];
	if ([type isEqualToString:@"head"])
		return [NSColor colorWithCalibratedRed: 0Xaa/256.0 green:0Xf2/256.0 blue: 0X54/256.0 alpha: 1.0];
	else if ([type isEqualToString:@"remote"])
		return [NSColor colorWithCalibratedRed: 0xb2/256.0 green:0Xdf/256.0 blue: 0Xff/256.0 alpha: 1.0];
	else if ([type isEqualToString:@"tag"])
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xed/256.0 blue: 0X4f/256.0 alpha: 1.0];
	
	return [NSColor yellowColor];
}

-(NSArray *)rectsForRefsinRect:(NSRect) rect;
{
	NSMutableArray *array = [NSMutableArray array];
	
	static const int ref_padding = 10;
	static const int ref_spacing = 2;
	
	NSRect lastRect = rect;
	lastRect.origin.x = round(lastRect.origin.x) - 0.5;
	lastRect.origin.y = round(lastRect.origin.y) - 0.5;
	
	for (PBGitRef *ref in self.objectValue.refs) {
		NSMutableDictionary* attributes = [self attributesForRefLabelSelected:NO];
		NSSize textSize = [[ref shortName] sizeWithAttributes:attributes];
		
		NSRect newRect = lastRect;
		newRect.size.width = textSize.width + ref_padding;
		newRect.size.height = textSize.height;
		newRect.origin.y = rect.origin.y + (rect.size.height - newRect.size.height) / 2;
		
		[array addObject:[NSValue valueWithRect:newRect]];
		lastRect = newRect;
		lastRect.origin.x += (int)lastRect.size.width + ref_spacing;
	}
	
	return array;
}

- (void) drawLabelAtIndex:(int)index inRect:(NSRect)rect
{
	NSArray *refs = self.objectValue.refs;
	PBGitRef *ref = [refs objectAtIndex:index];
	
	NSMutableDictionary* attributes = [self attributesForRefLabelSelected:[self isHighlighted]];
	NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:rect cornerRadius: 2.0];
	[[self colorForRef:ref] set];
	[border fill];
	
	[[ref shortName] drawInRect:rect withAttributes:attributes];
	[border stroke];	
}

- (void) drawRefsInRect: (NSRect *)refRect
{
	[[NSColor blackColor] setStroke];

	NSRect lastRect;
	int index = 0;
	for (NSValue *rectValue in [self rectsForRefsinRect:*refRect])
	{
		NSRect rect = [rectValue rectValue];
		[self drawLabelAtIndex:index inRect:rect];
		lastRect = rect;
		++index;
	}
	refRect->size.width -= lastRect.origin.x - refRect->origin.x + lastRect.size.width;
	refRect->origin.x    = lastRect.origin.x + lastRect.size.width;
}

- (void) drawWithFrame: (NSRect) rect inView:(NSView *)view
{
	cellInfo = [self.objectValue lineInfo];
	
	if (cellInfo && ![controller hasNonlinearPath]) {
		float pathWidth = 10 + 10 * cellInfo.numColumns;

		NSRect ownRect;
		NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

		int i;
		struct PBGitGraphLine *lines = cellInfo.lines;
		for (i = 0; i < cellInfo.nLines; i++) {
			if (lines[i].upper == 0)
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: ownRect.size.height color: lines[i].colorIndex];
			else
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: 0 color:lines[i].colorIndex];
		}

		if (cellInfo.sign == '<' || cellInfo.sign == '>')
			[self drawTriangleInRect: ownRect sign: cellInfo.sign];
		else
			[self drawCircleInRect: ownRect];
	}


	if ([self.objectValue refs] && [[self.objectValue refs] count])
		[self drawRefsInRect:&rect];

	// Still use this superclass because of hilighting differences
	//_contents = [self.objectValue subject];
	//[super drawWithFrame:rect inView:view];
	[textCell setObjectValue: [self.objectValue subject]];
	[textCell setHighlighted: [self isHighlighted]];
	[textCell drawWithFrame:rect inView: view];
}

- (void) setObjectValue: (PBGitCommit*)object {
	[super setObjectValue:[NSValue valueWithNonretainedObject:object]];
}

- (PBGitCommit*) objectValue {
    return [[super objectValue] nonretainedObjectValue];
}

- (int) indexAtX:(float)x
{
	cellInfo = [self.objectValue lineInfo];
	float pathWidth = 0;
	if (cellInfo && ![controller hasNonlinearPath])
		pathWidth = 10 + 10 * cellInfo.numColumns;

	int index = 0;
	NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);
	for (NSValue *rectValue in [self rectsForRefsinRect:refRect])
	{
		NSRect rect = [rectValue rectValue];
		if (x >= rect.origin.x && x <= (rect.origin.x + rect.size.width))
			return index;
		++index;
	}

	return -1;
}

- (NSRect) rectAtIndex:(int)index
{
	cellInfo = [self.objectValue lineInfo];
	float pathWidth = 0;
	if (cellInfo && ![controller hasNonlinearPath])
		pathWidth = 10 + 10 * cellInfo.numColumns;
	NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);

	return [[[self rectsForRefsinRect:refRect] objectAtIndex:index] rectValue];
}

# pragma mark context menu delegate methods

- (NSMenu *) menuForEvent:(NSEvent *)event inRect:(NSRect)rect ofView:(NSView *)view
{
	if (!contextMenuDelegate)
		return [self menu];

	int i = [self indexAtX:[view convertPointFromBase:[event locationInWindow]].x];
	if (i < 0)
		return [self menu];

	id ref = [[[self objectValue] refs] objectAtIndex:i];
	if (!ref)
		return [self menu];

	NSArray *items = [contextMenuDelegate menuItemsForRef:ref commit:[self objectValue]];
	NSMenu *menu = [[NSMenu alloc] init];
	for (NSMenuItem *item in items)
		[menu addItem:item];
	return menu;

	return [self menu];
}
@end
