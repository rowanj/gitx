//
//  PBGitXMessageSheet.m
//  GitX
//
//  Created by BrotherBard on 7/4/10.
//  Copyright 2010 BrotherBard. All rights reserved.
//

#import "PBGitXMessageSheet.h"


#define MaxScrollViewHeight 125.0f


@interface PBGitXMessageSheet ()

- (void)setInfoString:(NSString *)info;
- (void)resizeWindow;

@end

@implementation PBGitXMessageSheet

@synthesize iconView;
@synthesize messageField;
@synthesize infoView;
@synthesize scrollView;


#pragma mark -
#pragma mark PBGitXMessageSheet

+ (void)beginMessageSheetForRepo:(PBGitRepository *)repo
				 withMessageText:(NSString *)message
						infoText:(NSString *)info
{
	PBGitXMessageSheet *sheet = [[self alloc] initWithWindowNibName:@"PBGitXMessageSheet"
															forRepo:repo];
	[sheet beginMessageSheetWithMessageText:message
								   infoText:info];
}


+ (void)beginMessageSheetForRepo:(PBGitRepository *)repo
					   withError:(NSError *)error
{
	PBGitXMessageSheet *sheet = [[self alloc] initWithWindowNibName:@"PBGitXMessageSheet" forRepo:repo];
	[sheet beginMessageSheetWithMessageText:[error localizedDescription]
								   infoText:[error localizedRecoverySuggestion]];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
					forRepo:(PBGitRepository *)repo
{
	self = [super initWithWindowNibName:windowNibName forRepo:repo];
	if (!self)
		return nil;
	
	
	
	return self;
}

- (IBAction)closeMessageSheet:(id)sender
{
	[self hide];
}



#pragma mark Private

- (void)beginMessageSheetWithMessageText:(NSString *)message infoText:(NSString *)info;
{
	[self window];
	
	[self.messageField setStringValue:message];
	[self setInfoString:info];
	[self resizeWindow];
		
	[self show];
}


- (void)setInfoString:(NSString *)info
{
	NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]]
														   forKey:NSFontAttributeName];
	NSAttributedString *attributedInfoString = [[NSAttributedString alloc] initWithString:info attributes:attributes];
	[[self.infoView textStorage] setAttributedString:attributedInfoString];
}


- (void)resizeWindow
{
	// resize for message text
	NSRect messageFrame = [self.messageField frame];
	NSSize boundingSize = messageFrame.size;
	boundingSize.height = 0.0f;
	NSAttributedString *attributedTitle = [self.messageField attributedStringValue];
	NSRect boundingRect = [attributedTitle boundingRectWithSize:boundingSize options:NSStringDrawingUsesLineFragmentOrigin];
	CGFloat heightDelta = boundingRect.size.height - messageFrame.size.height;
	if (heightDelta > 0.0f) {
		messageFrame.size.height += heightDelta;
		messageFrame.origin.y -= heightDelta;
		[self.messageField setFrame:messageFrame];
		
		NSRect scrollFrame = [self.scrollView frame];
		scrollFrame.size.height -= heightDelta;
		[self.scrollView setFrame:scrollFrame];
		
		NSRect windowFrame = [[self window] frame];
		windowFrame.size.height += heightDelta;
		[[self window] setFrame:windowFrame display:NO];
	}
	
	// resize for info text
	NSRect scrollFrame = [self.scrollView frame];
	boundingSize = [self.scrollView bounds].size;
	boundingSize.height = 0.0f;
	NSAttributedString *attributedInfo = [[self.infoView layoutManager] attributedString];
	boundingRect = [attributedInfo boundingRectWithSize:boundingSize options:NSStringDrawingUsesLineFragmentOrigin];
	heightDelta = boundingRect.size.height - scrollFrame.size.height;
	if (heightDelta > MaxScrollViewHeight)
		heightDelta = MaxScrollViewHeight;
	if (heightDelta > 0.0f) {
		NSRect windowFrame = [[self window] frame];
		windowFrame.size.height += heightDelta;
		[[self window] setFrame:windowFrame display:NO];
	}
	[self.infoView scrollRangeToVisible:NSMakeRange(0, 0)];
}


@end
