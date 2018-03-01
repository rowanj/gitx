//
//  PBGitXMessageSheet.m
//  GitX
//
//  Created by BrotherBard on 7/4/10.
//  Copyright 2010 BrotherBard. All rights reserved.
//

#import "PBGitXMessageSheet.h"
#import "PBTask.h"


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


+ (void)beginSheetWithMessage:(NSString *)message
						 info:(NSString *)info
			 windowController:(PBGitWindowController *)windowController
{
	[self beginSheetWithMessage:message
						   info:info
			   windowController:windowController
			  completionHandler:nil];
}

+ (void)beginSheetWithError:(NSError *)error
		   windowController:(PBGitWindowController *)windowController
{
	[self beginSheetWithError:error windowController:windowController completionHandler:nil];
}

+ (void)beginSheetWithMessage:(NSString *)message
						 info:(NSString *)info
			 windowController:(PBGitWindowController *)windowController
			completionHandler:(RJSheetCompletionHandler)handler
{
	PBGitXMessageSheet *sheet = [[self alloc] initWithWindowNibName:@"PBGitXMessageSheet" windowController:windowController];
	[sheet beginMessageSheetWithMessageText:message
								   infoText:info
						  completionHandler:handler];
}

+ (void)beginSheetWithError:(NSError *)error
		   windowController:(PBGitWindowController *)windowController
		  completionHandler:(RJSheetCompletionHandler)handler
{
	PBGitXMessageSheet *sheet = [[self alloc] initWithWindowNibName:@"PBGitXMessageSheet" windowController:windowController];

	NSMutableArray *messageParts = [NSMutableArray array];

	if (error.localizedFailureReason)
		[messageParts addObject:error.localizedFailureReason];

	if (error.localizedRecoverySuggestion) {
		NSString *message = NSLocalizedString(@"Maybe you could try the following:", @"PBGitXMessageSheet - localized recovery suggestion header");
		[message stringByAppendingString:@"\n"];
		[message stringByAppendingString:error.localizedRecoverySuggestion];
		[messageParts addObject:message];
	}

	NSError *taskError = error.userInfo[NSUnderlyingErrorKey];
	if (taskError && taskError.domain == PBTaskErrorDomain) {
		[messageParts addObject:NSLocalizedString(@"The underlying task failed:", @"PBGitXMessageSheet - task failed header")];
		if (taskError.code == PBTaskNonZeroExitCodeError) {
			NSString *message = NSLocalizedString(@"Return code: %d", @"PBGitXMessageSheet - task return code header");
			message = [NSString stringWithFormat:message, taskError.userInfo[PBTaskTerminationStatusKey]];
			[messageParts addObject:message];
			message = NSLocalizedString(@"Output:", @"PBGitXMessageSheet - task output header");
			message = [message stringByAppendingString:taskError.userInfo[PBTaskTerminationOutputKey]];
			[messageParts addObject:message];
		} else {
			[messageParts addObject:taskError.localizedDescription];
			[messageParts addObject:taskError.localizedFailureReason];
		}
	}

	NSString *infoText = [messageParts componentsJoinedByString:@"\n\n"];

	[sheet beginMessageSheetWithMessageText:[error localizedDescription]
								   infoText:infoText
						  completionHandler:handler];
}

- (IBAction)closeMessageSheet:(id)sender
{
	[self acceptSheet:sender];
}



#pragma mark Private

- (void)beginMessageSheetWithMessageText:(NSString *)message
								infoText:(NSString *)info
					   completionHandler:(RJSheetCompletionHandler)handler;
{
	[self window];
	
	[self.messageField setStringValue:message];
	[self setInfoString:info];
	[self resizeWindow];
		
	[self beginSheetWithCompletionHandler:handler];
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
