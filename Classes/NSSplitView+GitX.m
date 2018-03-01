//
//  NSSplitView+GitX.m
//  GitX
//
//  Created by Kent Sutherland on 4/25/17.
//
//

#import "NSSplitView+GitX.h"

@implementation NSSplitView (GitX)

// Taken from http://stackoverflow.com/questions/16587058/nssplitview-auto-saving-divider-positions-doesnt-work-with-auto-layout-enable
// Without this split views don't automatically restore for windows that aren't reopened by state restoration
- (void)pb_restoreAutosavedPositions
{
	NSString *key = [NSString stringWithFormat:@"NSSplitView Subview Frames %@", self.autosaveName];
	NSArray<NSString *> *subviewFrames = [[NSUserDefaults standardUserDefaults] objectForKey:key];

	// the last frame is skipped because I have one less divider than I have frames
	for (NSInteger i = 0; i < subviewFrames.count; i++) {
		if (i < self.subviews.count) { // safety-check (in case number of views have been removed while dev)
			// this is the saved frame data - it's an NSString
			NSString *frameString = subviewFrames[i];
			NSArray<NSString *> *components = [frameString componentsSeparatedByString:@", "];

			// Manage the 'hidden state' per view
			BOOL hidden = [components[4] boolValue];
			NSView *subview = [self subviews][i];

			[subview setHidden:hidden];

			// Set height (horizontal) or width (vertical)
			if(![self isVertical]) {
				CGFloat height = [components[3] floatValue];

				[subview setFrameSize:NSMakeSize(subview.frame.size.width, height)];
			} else {
				CGFloat width = [components[2] floatValue];

				[subview setFrameSize:NSMakeSize(width, subview.frame.size.height)];
			}
		}
	}
}

@end
