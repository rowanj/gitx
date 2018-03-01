//
//  OpenRecentController.m
//  GitX
//
//  Created by Hajo Nils Krabbenhöft on 07.10.10.
//  Copyright 2010 spratpix GmbH & Co. KG. All rights reserved.
//

#import "OpenRecentController.h"
#import "PBGitDefaults.h"

@implementation OpenRecentController

@synthesize currentResults;
@synthesize possibleResults;

- (id)init
{
	self = [super initWithWindowNibName:@"OpenRecentPopup"];
	if (!self)
		return nil;
	
	currentResults = [NSMutableArray array];
	
	possibleResults = [NSMutableArray array];
	for (NSURL *url in [[NSDocumentController sharedDocumentController] recentDocumentURLs]) {
		if ([url checkResourceIsReachableAndReturnError:NULL]) {
			[possibleResults addObject: url];
		}
	}
	
	
	return self;
}

- (void) show
{
	[self doSearch:self];
	[self.window makeKeyAndOrderFront:self];
}

- (void) hide
{
	[[self window] orderOut:self];
}

- (IBAction)doSearch:(id) sender
{
	NSString *searchString = [searchField stringValue];
	
	while( [currentResults count] > 0 ) [currentResults removeLastObject];
	
    for(NSURL* url in possibleResults){
		NSString* label = [url lastPathComponent];
		if([searchString length] > 0) {
			NSRange aRange = [label rangeOfString: searchString options: NSCaseInsensitiveSearch];
			if (aRange.location == NSNotFound) continue;
		}
		[currentResults addObject: url];
    }   
	
	if( [currentResults count] > 0 )
		selectedResult = [currentResults objectAtIndex:0];
	else
		selectedResult = nil;
	
	[resultViewer reloadData];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
    [resultViewer setTarget:self];
    [resultViewer setDoubleAction:@selector(tableDoubleClick:)];
}

- (IBAction) tableDoubleClick:(id)sender 
{
	[self changeSelection:self];
	if(selectedResult != nil) {
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:selectedResult display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {

		}];
	}
	[self hide];
}

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector {
    BOOL result = NO;
    if (commandSelector == @selector(insertNewline:)) {
		if(selectedResult != nil) {
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:selectedResult display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {

			}];
		}
		[self hide];
//		[searchWindow makeKeyAndOrderFront: nil];
		result = YES;
    }
	else if(commandSelector == @selector(cancelOperation:)) {
		[self hide];
		result = YES;
	}
	else if(commandSelector == @selector(moveUp:)) {
		if(selectedResult != nil) {
			NSUInteger index = [currentResults indexOfObject:selectedResult] - 1;
			if (index > 0) {
				index -= 1;
			}
			selectedResult = [currentResults objectAtIndex:index];
			[resultViewer selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:FALSE];
			[resultViewer scrollRowToVisible:index];
		}
		result = YES;
	}
	else if(commandSelector == @selector(moveDown:)) {
		if(selectedResult != nil) {
			NSUInteger index = [currentResults indexOfObject:selectedResult] + 1;
			if(index >= [currentResults count]) index = [currentResults count] - 1;
			selectedResult = [currentResults objectAtIndex:index];
			[resultViewer selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:FALSE];
			[resultViewer scrollRowToVisible:index];
		}
		result = YES;
	}
    return result;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{	
    id theValue = nil;
    NSParameterAssert(rowIndex >= 0 && rowIndex < [currentResults count]);
	
    NSURL* row = [currentResults objectAtIndex:rowIndex];
	if( [[aTableColumn identifier] isEqualToString: @"icon"] ) {
		id icon;
		NSError* error;
		[row getResourceValue:&icon forKey:NSURLEffectiveIconKey error:&error];
		return icon;
	} else if( [[aTableColumn identifier] isEqualToString: @"label"] ) {
		return [row lastPathComponent];
	}
    return theValue;
	
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [currentResults count];
}

- (IBAction)changeSelection:(id) sender {
	NSInteger i = resultViewer.selectedRow;
	if(i >= 0 && i < currentResults.count)
		selectedResult = [currentResults objectAtIndex: i];
	else 
		selectedResult = nil;
}

@end
