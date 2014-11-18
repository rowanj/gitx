//
//  PBGitRevisionCell.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevisionCell.h"
#import "PBGitRef.h"
#import "PBGitCommit.h"
#import "PBGitRevSpecifier.h"
#import "RoundedRectangle.h"
#import "GitXTextFieldCell.h"

#import "NSColor+RGB.h"

const int COLUMN_WIDTH = 10;
const BOOL ENABLE_SHADOW = NO;
const BOOL SHUFFLE_COLORS = NO;

@implementation PBGitRevisionCell

- (id) initWithCoder: (id) coder
{
	self = [super initWithCoder:coder];
	textCell = [[GitXTextFieldCell alloc] initWithCoder:coder];
	return self;
}

#define HEX_COLOR(hex)                        \
{                                             \
	(CGFloat)((((hex) >> 16) & 0xFF) / 255.0f), \
	(CGFloat)((((hex) >> 8)  & 0xFF) / 255.0f), \
	(CGFloat)((((hex) >> 0)  & 0xFF) / 255.0f)  \
}

+ (NSArray *)laneColors
{
	static const CGFloat colorPalette[][3] = {
		HEX_COLOR(0xF00000), // red
		HEX_COLOR(0xFF8000), // tangerine (orange)
		HEX_COLOR(0xE0D030), // yellow
		HEX_COLOR(0x008000), // clover (green)
		HEX_COLOR(0x00D0D0), // cyan
		HEX_COLOR(0x0000FF), // blueberry (navy)
		HEX_COLOR(0x0080FF), // aqua (sky blue)
		HEX_COLOR(0x8000FF), // grape (violet)
		HEX_COLOR(0xFF00FF), // magenta
	};
	static NSArray *laneColors = nil;
	if (!laneColors) {
		NSMutableArray *colors = [NSMutableArray new];
		for (size_t i = 0; i < sizeof(colorPalette)/sizeof(*colorPalette); ++i) {
			NSColor *newColor = [NSColor colorWithCalibratedRed:colorPalette[i][0] green:colorPalette[i][1] blue:colorPalette[i][2] alpha:1.0f];
			[colors addObject:newColor];
		}
		if (SHUFFLE_COLORS) {
			NSMutableArray *shuffledColors = [NSMutableArray new];
			while (colors.count) {
				uint32_t index = arc4random_uniform(colors.count);
				[shuffledColors addObject:colors[index]];
				[colors removeObjectAtIndex:index];
			}
			colors = shuffledColors;
		}
		laneColors = [NSArray arrayWithArray:colors];
	}

	return laneColors;
}

+ (NSShadow *)shadow
{
	static NSShadow *shadow = nil;
	if (!shadow) {
		shadow = [NSShadow new];
		[shadow setShadowOffset:NSMakeSize(.5, -.5)];
		[shadow setShadowBlurRadius:2];
		[shadow setShadowColor:[NSColor colorWithWhite:0 alpha:.7]];
	}
	return shadow;
}
+ (NSShadow *)textInsetShadow
{
	static NSShadow *shadow = nil;
	if (!shadow) {
		shadow = [NSShadow new];
		[shadow setShadowOffset:NSMakeSize(0, -.5)];
		[shadow setShadowBlurRadius:0];
		[shadow setShadowColor:[NSColor colorWithWhite:1 alpha:.5]];
	}
	return shadow;
}
+ (NSShadow *)lineShadow
{
	static NSShadow *shadow = nil;
	if (!shadow) {
		shadow = [NSShadow new];
	}
	return shadow;
}

- (void) drawLineFromColumn: (int) from toColumn: (int) to inRect: (NSRect) r offset: (int) offset color: (int) c
{
	NSPoint origin = r.origin;
	
	NSPoint source = NSMakePoint(origin.x + COLUMN_WIDTH * from, origin.y + offset);
	NSPoint center = NSMakePoint( origin.x + COLUMN_WIDTH * to, origin.y + r.size.height * 0.5 + 0.5);

	if (ENABLE_SHADOW) {
		[NSGraphicsContext saveGraphicsState];
		[[[self class] lineShadow] set];
	}
	NSArray* colors = [PBGitRevisionCell laneColors];
	[(NSColor*)[colors objectAtIndex: (c % [colors count])] set];
	
	NSBezierPath * path = [NSBezierPath bezierPath];
	[path setLineWidth:2];
	[path setLineCapStyle:NSRoundLineCapStyle];
	[path moveToPoint: source];
	[path lineToPoint: center];
	[path stroke];

	if (ENABLE_SHADOW) {
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (BOOL) isCurrentCommit
{
	GTOID *thisSha = [self.objectValue sha];

	PBGitRepository* repository = [self.objectValue repository];
	GTOID *currentSha = [repository headSHA];

	return [currentSha isEqual:thisSha];
}

- (void) drawCircleInRect: (NSRect) r color: (int) c
{
	int p = cellInfo.position;
	NSPoint origin = r.origin;
	NSPoint columnOrigin = { origin.x + COLUMN_WIDTH * p, origin.y};

	NSRect oval = { columnOrigin.x - 5, columnOrigin.y + r.size.height * 0.5 - 5, 10, 10};

	NSBezierPath * path = [NSBezierPath bezierPathWithOvalInRect:oval];
	if (ENABLE_SHADOW && false) {
		[NSGraphicsContext saveGraphicsState];
		[[[self class] shadow] set];
	}
	NSArray* colors = [PBGitRevisionCell laneColors];
	[(NSColor*)[colors objectAtIndex: (c % [colors count])] set];
	[path fill];
	if (ENABLE_SHADOW && false) {
		[NSGraphicsContext restoreGraphicsState];
	}
	
	NSRect smallOval = { columnOrigin.x - 4, columnOrigin.y + r.size.height * 0.5 - 4, 8, 8};

	if ( [self isCurrentCommit ] ) {
		[[NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xa6/256.0 blue: 0X4f/256.0 alpha: 1.0] set];
	} else {
		[[NSColor whiteColor] set];
	}

	NSBezierPath *smallPath = [NSBezierPath bezierPathWithOvalInRect:smallOval];
	[smallPath fill];

}

- (void) drawTriangleInRect: (NSRect) r sign: (char) sign color: (int) c
{
	int p = cellInfo.position;
	int columnHeight = 10;
	int columnWidth = 8;

	NSPoint top;
	if (sign == '<')
		top.x = round(r.origin.x) + 10 * p + 4;
	else {
		top.x = round(r.origin.x) + 10 * p - 4;
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
	NSArray* colors = [PBGitRevisionCell laneColors];
	[(NSColor*)[colors objectAtIndex: (c % [colors count])] set];
	[path setLineWidth: 2];
	[path stroke];
}

- (NSMutableDictionary*) attributesForRefLabelSelected: (BOOL) selected
{
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
	NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	[style setAlignment:NSCenterTextAlignment];
	[attributes setObject:style forKey:NSParagraphStyleAttributeName];
	[attributes setObject:[NSFont boldSystemFontOfSize:9] forKey:NSFontAttributeName];
	[attributes setObject:[NSColor colorWithWhite:0 alpha:.6] forKey:NSForegroundColorAttributeName];

	if (ENABLE_SHADOW) {
		attributes[NSShadowAttributeName] = [[self class] textInsetShadow];
	}

	return attributes;
}

- (NSColor*) colorForRef: (PBGitRef*) ref
{
	BOOL isHEAD = [ref.ref isEqualToString:[[[controller repository] headRef] simpleRef]];

	if (isHEAD) {
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xa6/256.0 blue: 0X4f/256.0 alpha: 1.0];
	}

	NSString* type = [ref type];
	if ([type isEqualToString:@"head"]) {
		return [NSColor colorWithCalibratedRed: 0X9a/256.0 green:0Xe2/256.0 blue: 0X84/256.0 alpha: 1.0];
	} else if ([type isEqualToString:@"remote"]) {
		return [NSColor colorWithCalibratedRed: 0xa2/256.0 green:0Xcf/256.0 blue: 0Xef/256.0 alpha: 1.0];
	} else if ([type isEqualToString:@"tag"]) {
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xed/256.0 blue: 0X6f/256.0 alpha: 1.0];
	}
	
	return [NSColor yellowColor];
}

-(NSArray *)rectsForRefsinRect:(NSRect) rect;
{
	NSMutableArray *array = [NSMutableArray array];
	
	static const int ref_padding = 10;
	static const int ref_spacing = 4;
	
	NSRect lastRect = rect;
	lastRect.origin.x = round(lastRect.origin.x);
	lastRect.origin.y = round(lastRect.origin.y);
	
	for (PBGitRef *ref in self.objectValue.refs) {
		NSMutableDictionary* attributes = [self attributesForRefLabelSelected:NO];
		NSSize textSize = [[ref shortName] sizeWithAttributes:attributes];
		
		NSRect newRect = lastRect;
		newRect.size.width = textSize.width + ref_padding;
		newRect.size.height = textSize.height + 1;
		newRect.origin.y = ceil(rect.origin.y + (rect.size.height - newRect.size.height) / 2);
		
		if (NSContainsRect(rect, newRect)) {
			[array addObject:[NSValue valueWithRect:newRect]];
			lastRect = newRect;
			lastRect.origin.x += (int)lastRect.size.width + ref_spacing;
		}
	}
	
	return array;
}

- (void) drawLabelAtIndex:(int)index inRect:(NSRect)rect
{
	NSArray *refs = self.objectValue.refs;
	PBGitRef *ref = [refs objectAtIndex:index];
	
	NSMutableDictionary* attributes = [self attributesForRefLabelSelected:[self isHighlighted]];
	NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:rect cornerRadius: 3.0];
	[[self colorForRef:ref] set];
	

	if (ENABLE_SHADOW) {
		[NSGraphicsContext saveGraphicsState];
		[[[self class] shadow] set];
	}
	[border fill];
	if (ENABLE_SHADOW) {
		[NSGraphicsContext restoreGraphicsState];
	}
//	[[NSColor blackColor] set];
//	[border stroke];
	[[ref shortName] drawInRect:rect withAttributes:attributes];
}

- (void) drawRefsInRect: (NSRect *)refRect
{
	[[NSColor blackColor] setStroke];

	NSRect lastRect = NSMakeRect(0, 0, 0, 0);
	int index = 0;
	for (NSValue *rectValue in [self rectsForRefsinRect:*refRect])
	{
		NSRect rect = [rectValue rectValue];
		[self drawLabelAtIndex:index inRect:rect];
		lastRect = rect;
		++index;
	}

    // Only update rect to account for drawn refs if necessary to push
    // subsequent content to the right.
    if (index > 0) {
		const CGFloat PADDING = 4;
        refRect->size.width -= lastRect.origin.x - refRect->origin.x + lastRect.size.width - PADDING;
        refRect->origin.x    = lastRect.origin.x + lastRect.size.width + PADDING;
    }
}

- (void) drawWithFrame: (NSRect) rect inView:(NSView *)view
{
	cellInfo = [self.objectValue lineInfo];
	
	if (cellInfo && ![controller hasNonlinearPath]) {
		float pathWidth = 10 + COLUMN_WIDTH * cellInfo.numColumns;

		NSRect ownRect;
		NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

		int i, cellColorIndex = 0;
		struct PBGitGraphLine *lines = cellInfo.lines;
		for (i = 0; i < cellInfo.nLines; i++) {
			int colorIndex = lines[i].colorIndex;
			if (lines[i].from == cellInfo.position && lines[i].to == cellInfo.position)
				cellColorIndex = colorIndex;
			if (lines[i].upper == 0)
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: ownRect.size.height color: colorIndex];
			else
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: 0 color: colorIndex];
		}

		if (cellInfo.sign == '<' || cellInfo.sign == '>')
			[self drawTriangleInRect: ownRect sign: cellInfo.sign color: cellColorIndex];
		else
			[self drawCircleInRect: ownRect color: cellColorIndex];
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

	int i = [self indexAtX:[view convertPoint:[event locationInWindow] fromView:nil].x - rect.origin.x];

	id ref = nil;
	if (i >= 0)
		ref = [[[self objectValue] refs] objectAtIndex:i];

	NSArray *items = nil;
	if (ref)
		items = [contextMenuDelegate menuItemsForRef:ref];
	else
		items = [contextMenuDelegate menuItemsForCommit:[self objectValue]];

	NSMenu *menu = [[NSMenu alloc] init];
	[menu setAutoenablesItems:NO];
	for (NSMenuItem *item in items)
		[menu addItem:item];
	return menu;
}
@end
