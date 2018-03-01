//
//  PBRemoteProgressSheetController.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/6/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBRemoteProgressSheet.h"

@interface PBRemoteProgressSheet ()

@property (weak) IBOutlet NSTextField *descriptionField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property NSString *title;
@property NSString *progressDescription;

@end

@implementation PBRemoteProgressSheet

+ (instancetype)progressSheetWithTitle:(NSString *)title description:(NSString *)description windowController:(PBGitWindowController *)windowController {
	return [[self alloc] initWithTitle:title description:description windowController:windowController];
}

+ (instancetype)progressSheetWithTitle:(NSString *)title description:(NSString *)description {
	return [[self alloc] initWithTitle:title description:description windowController:nil];
}

- (instancetype)initWithTitle:(NSString *)title description:(NSString *)description windowController:(PBGitWindowController *)windowController
{
	if (windowController) {
		self = [self initWithWindowNibName:@"PBRemoteProgressSheet" windowController:windowController];
	} else {
		self = [self initWithWindowNibName:@"PBRemoteProgressSheet"];
	}
	if (!self) return nil;

	_title = title;
	_progressDescription = description;

	return self;
}

- (void)beginProgressSheetForBlock:(PBProgressSheetExecutionHandler)executionBlock completionHandler:(void (^)(NSError *))completionHandler
{
	__block NSError *executionError = nil;

	// Dispatch the actual execution block
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		executionError = executionBlock();
		dispatch_async(dispatch_get_main_queue(), ^{
			[self acceptSheet:self];
		});
	});

	// Bring up our progress sheet
	[self beginSheetWithCompletionHandler:^(id sheet, NSModalResponse returnCode) {
		completionHandler(executionError);
	}];
}

- (void)awakeFromNib {
	[self window]; // loads the window (if it wasn't already)

	// resize window if the description is larger than the default text field
	NSRect originalFrame = self.descriptionField.frame;
	self.descriptionField.stringValue = self.progressDescription;

	NSAttributedString *attributedTitle = self.descriptionField.attributedStringValue;
	NSSize boundingSize = originalFrame.size;
	boundingSize.height = 0.0f;
	NSRect boundingRect = [attributedTitle boundingRectWithSize:boundingSize
														options:NSStringDrawingUsesLineFragmentOrigin];
	CGFloat heightDelta = boundingRect.size.height - originalFrame.size.height;
	if (heightDelta > 0.0f) {
		NSRect windowFrame = [[self window] frame];
		windowFrame.size.height += heightDelta;
		[[self window] setFrame:windowFrame display:NO];
	}

	[self.progressIndicator startAnimation:nil];
}

@end
