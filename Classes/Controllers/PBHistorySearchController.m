//
//  PBHistorySearchController.m
//  GitX
//
//  Created by Nathan Kinsinger on 8/21/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <QuartzCore/CoreAnimation.h>

#import "PBHistorySearchController.h"
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitDefaults.h"
#import "PBCommitList.h"
#import "PBEasyPipe.h"
#import "PBGitBinary.h"
#import "PBGitCommit.h"

@interface PBHistorySearchController ()

- (void)selectNextResultInDirection:(NSInteger)direction;

- (void)updateUI;
- (void)setupSearchMenuTemplate;

- (void)startBasicSearch;
- (void)startBackgroundSearch;
- (void)clearProgressIndicator;

- (void)showSearchRewindPanelReverse:(BOOL)isReversed;

@end


#define kGitXSearchDirectionNext 1
#define kGitXSearchDirectionPrevious -1

#define kGitXBasicSearchLabel @"Subject, Author, SHA"
#define kGitXPickaxeSearchLabel @"Commit (pickaxe)"
#define kGitXRegexSearchLabel @"Commit (pickaxe regex)"
#define kGitXPathSearchLabel @"File path"

#define kGitXSearchArrangedObjectsContext @"GitXSearchArrangedObjectsContext"


@implementation PBHistorySearchController

@synthesize historyController;
@synthesize commitController;

@synthesize searchField;
@synthesize stepper;
@synthesize numberOfMatchesField;
@synthesize progressIndicator;


#pragma mark -
#pragma mark Public methods

- (BOOL)isRowInSearchResults:(NSInteger)rowIndex
{
	return [results containsIndex:rowIndex];
}

- (BOOL)hasSearchResults
{
	return ([results count] > 0);
}

- (void)selectSearchMode:(id)sender
{
	self.searchMode = [(NSView*)sender tag];
	[self updateSearch:self];
}

- (void)selectNextResult
{
	[self selectNextResultInDirection:kGitXSearchDirectionNext];
}

- (void)selectPreviousResult
{
	[self selectNextResultInDirection:kGitXSearchDirectionPrevious];
}

- (IBAction)stepperPressed:(id)sender
{
	NSInteger selectedSegment = [sender selectedSegment];

	if (selectedSegment == 0)
		[self selectPreviousResult];
	else
		[self selectNextResult];
}

- (void)clearSearch
{
	[searchField setStringValue:@""];
	if (results) {
		results = nil;
		[historyController.commitList reloadData];
	}
	[self updateUI];
}

- (IBAction)updateSearch:(id)sender
{
	if (self.searchMode == kGitXBasicSeachMode)
		[self startBasicSearch];
	else
		[self startBackgroundSearch];
}

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode
{
	if (searchString && ![searchString isEqualToString:@""]) {
		self.searchMode = mode;
		[searchField setStringValue:searchString];
		// use performClick: so that the search field will save it as a recent search
		[searchField performClick:self];
	}
}

- (void)awakeFromNib
{
	[self setupSearchMenuTemplate];
	self.searchMode = [PBGitDefaults historySearchMode];

	[self updateUI];

	[commitController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:kGitXSearchArrangedObjectsContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([(__bridge NSString *)context isEqualToString:kGitXSearchArrangedObjectsContext]) {
		// the objects in the commitlist changed so the result indexes are no longer valid
		[self clearSearch];
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}



#pragma mark -
#pragma mark Private methods

- (void)selectIndex:(NSUInteger)index
{
	if ([[commitController arrangedObjects] count] > index) {
		PBGitCommit *commit = [[commitController arrangedObjects] objectAtIndex:index];
		[historyController selectCommit:[commit sha]];
	}
}

- (void)selectNextResultInDirection:(NSInteger)direction
{
	if (![results count])
		return;

	NSUInteger selectedRow = [historyController.commitList selectedRow];
	if (selectedRow == NSNotFound) {
		[self selectIndex:[results firstIndex]];
		return;
	}

	NSUInteger currentResult = NSNotFound;
	if (direction == kGitXSearchDirectionNext)
		currentResult = [results indexGreaterThanIndex:selectedRow];
	else
		currentResult = [results indexLessThanIndex:selectedRow];

	if (currentResult == NSNotFound) {
		if (direction == kGitXSearchDirectionNext)
			currentResult = [results firstIndex];
		else
			currentResult = [results lastIndex];

		[self showSearchRewindPanelReverse:(direction != kGitXSearchDirectionNext)];
	}

	[self selectIndex:currentResult];
}

- (NSString *)numberOfMatchesString
{
	NSUInteger numberOfMatches = [results count];

	if (numberOfMatches == 0)
		return @"Not found";

	if (numberOfMatches == 1)
		return @"1 match";

	return [NSString stringWithFormat:@"%lu matches", numberOfMatches];
}

- (void)updateUI
{
	if ([[searchField stringValue] isEqualToString:@""]) {
		[numberOfMatchesField setHidden:YES];
		[stepper setHidden:YES];
	}
	else {
		[numberOfMatchesField setStringValue:[self numberOfMatchesString]];
		[numberOfMatchesField setHidden:NO];
		[stepper setHidden:NO];
		[historyController.commitList reloadData];
	}
	[self clearProgressIndicator];
}

// changes the selection to the next match after the current selected row unless the current row is already a match
- (void)updateSelectedResult
{
	NSString *searchString = [searchField stringValue];
	if ([searchString isEqualToString:@""]) {
		[self clearSearch];
		return;
	}

	if (![self isRowInSearchResults:[historyController.commitList selectedRow]])
		[self selectNextResult];

	[self updateUI];
}

- (void)setupSearchMenuTemplate
{
	NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;

	item = [[NSMenuItem alloc] initWithTitle:kGitXBasicSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:kGitXBasicSeachMode];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXPickaxeSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:kGitXPickaxeSearchMode];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXRegexSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:kGitXRegexSearchMode];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXPathSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:kGitXPathSearchMode];
    [searchMenu addItem:item];

    item = [NSMenuItem separatorItem];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:@"Recent Searches" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:@"Recents" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsMenuItemTag];
    [searchMenu addItem:item];

    item = [NSMenuItem separatorItem];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:@"Clear Recent Searches" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldClearRecentsMenuItemTag];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:@"No Recent Searches" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldNoRecentsMenuItemTag];
    [searchMenu addItem:item];

    [[searchField cell] setSearchMenuTemplate:searchMenu];
}

- (void)updateSearchMenuState
{
	NSMenu *searchMenu = [[searchField cell] searchMenuTemplate];
	if (!searchMenu)
		return;

	NSMenuItem *item;

	item = [searchMenu itemWithTag:kGitXBasicSeachMode];
	[item setState:(searchMode == kGitXBasicSeachMode) ? NSOnState : NSOffState];

	item = [searchMenu itemWithTag:kGitXPickaxeSearchMode];
	[item setState:(searchMode == kGitXPickaxeSearchMode) ? NSOnState : NSOffState];

	item = [searchMenu itemWithTag:kGitXRegexSearchMode];
	[item setState:(searchMode == kGitXRegexSearchMode) ? NSOnState : NSOffState];

	item = [searchMenu itemWithTag:kGitXPathSearchMode];
	[item setState:(searchMode == kGitXPathSearchMode) ? NSOnState : NSOffState];

    [[searchField cell] setSearchMenuTemplate:searchMenu];

	[PBGitDefaults setHistorySearchMode:searchMode];
}

- (void)updateSearchPlaceholderString
{
	switch (self.searchMode) {
		case kGitXPickaxeSearchMode:
			[[searchField cell] setPlaceholderString:kGitXPickaxeSearchLabel];
			break;
		case kGitXRegexSearchMode:
			[[searchField cell] setPlaceholderString:kGitXRegexSearchLabel];
			break;
		case kGitXPathSearchMode:
			[[searchField cell] setPlaceholderString:kGitXPathSearchLabel];
			break;
		default:
			[[searchField cell] setPlaceholderString:kGitXBasicSearchLabel];
			break;
	}
}

- (PBHistorySearchMode)searchMode
{
	return searchMode;
}

- (void)setSearchMode:(PBHistorySearchMode)mode
{
	if ((mode < kGitXBasicSeachMode) || (mode >= kGitXMaxSearchMode))
		mode = kGitXBasicSeachMode;

	searchMode = mode;
	[PBGitDefaults setHistorySearchMode:searchMode];

	[self updateSearchMenuState];
	[self updateSearchPlaceholderString];
}

- (void)searchTimerFired:(NSTimer*)theTimer
{
	[self.progressIndicator setHidden:NO];
	[self.progressIndicator startAnimation:self];
}

- (void)clearProgressIndicator
{
	[searchTimer invalidate];
	searchTimer = nil;
	[self.progressIndicator setHidden:YES];
	[self.progressIndicator stopAnimation:self];
}

- (void)startProgressIndicator
{
	[self clearProgressIndicator];
	[numberOfMatchesField setHidden:YES];
	[stepper setHidden:YES];
	searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(searchTimerFired:) userInfo:nil repeats:NO];
}



#pragma mark Basic Search

- (void)startBasicSearch
{
	NSString *searchString = [searchField stringValue];
	if ([searchString isEqualToString:@""]) {
		[self clearSearch];
		return;
	}

	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"subject CONTAINS[cd] %@ OR author CONTAINS[cd] %@ OR realSha BEGINSWITH[c] %@", searchString, searchString, searchString];

	NSUInteger index = 0;
	for (PBGitCommit *commit in [commitController arrangedObjects]) {
		if ([searchPredicate evaluateWithObject:commit])
			[indexes addIndex:index];
		index++;
	}

	results = indexes;

	[self updateSelectedResult];
}



#pragma mark Background Search

- (void)startBackgroundSearch
{
	if (backgroundSearchTask) {
		NSFileHandle *handle = [[backgroundSearchTask standardOutput] fileHandleForReading];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:handle];
		[backgroundSearchTask terminate];
	}

	NSString *searchString = [[searchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([searchString isEqualToString:@""]) {
		[self clearSearch];
		return;
	}

	results = nil;

	NSMutableArray *searchArguments = [NSMutableArray arrayWithObjects:@"log", @"--pretty=format:%H", nil];
	switch (self.searchMode) {
		case kGitXRegexSearchMode:
			[searchArguments addObject:@"--pickaxe-regex"];
		case kGitXPickaxeSearchMode:
			[searchArguments addObject:[NSString stringWithFormat:@"-S%@", searchString]];
			break;
		case kGitXPathSearchMode:
			[searchArguments addObject:@"--"];
			[searchArguments addObjectsFromArray:[searchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
			break;
		default:
			return;
	}

	backgroundSearchTask = [PBEasyPipe taskForCommand:[PBGitBinary path] withArgs:searchArguments inDir:[[historyController.repository fileURL] path]];
	[backgroundSearchTask launch];

	NSFileHandle *handle = [[backgroundSearchTask standardOutput] fileHandleForReading];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(parseBackgroundSearchResults:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle];
	[handle readToEndOfFileInBackgroundAndNotify];

	[self startProgressIndicator];
}

- (void)parseBackgroundSearchResults:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[notification object]];
	backgroundSearchTask = nil;

	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];

	NSString *resultsString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSArray *resultsArray = [resultsString componentsSeparatedByString:@"\n"];

	NSMutableSet *matches = [NSMutableSet new];
	for (NSString *resultSHA in resultsArray) {
		GTOID *resultOID = [GTOID oidWithSHA:resultSHA];
		if (resultOID) {
			[matches addObject:resultOID];
		}
	}

	NSArray *arrangedObjects = [commitController arrangedObjects];
	NSIndexSet *indexes = [arrangedObjects indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		PBGitCommit *commit = obj;
		return [matches containsObject:commit.sha];
	}];

	results = indexes;
	[self clearProgressIndicator];
	[self updateSelectedResult];
}



#pragma mark -
#pragma mark Rewind Panel

#define kRewindPanelSize 125.0f

- (void)closeRewindPanel
{
	[[[historyController view] window] removeChildWindow:rewindPanel];
	[rewindPanel close];
	rewindPanel = nil;
}

- (NSPanel *)rewindPanelReverse:(BOOL)isReversed
{
	NSRect windowFrame = [[[historyController view] window] frame];
	NSRect historyFrame = [[historyController view] convertRectToBase:[[historyController view] frame]];
	NSRect panelRect = NSMakeRect(0.0f, 0.0f, kRewindPanelSize, kRewindPanelSize);
	panelRect.origin.x = windowFrame.origin.x + historyFrame.origin.x + ((historyFrame.size.width - kRewindPanelSize) / 2.0f);
	panelRect.origin.y = windowFrame.origin.y + historyFrame.origin.y + ((historyFrame.size.height - kRewindPanelSize) / 2.0f);

	NSPanel *panel = [[NSPanel alloc] initWithContentRect:panelRect
												styleMask:NSBorderlessWindowMask
												  backing:NSBackingStoreBuffered 
													defer:YES];
	[panel setIgnoresMouseEvents:YES];
	[panel setOneShot:YES];
	[panel setOpaque:NO];
	[panel setBackgroundColor:[NSColor clearColor]];
	[panel setHasShadow:NO];
	[panel useOptimizedDrawing:YES];
	[panel setAlphaValue:0.0f];

	NSBox *box = [[NSBox alloc] initWithFrame:[[panel contentView] frame]];
	[box setBoxType:NSBoxCustom];
	[box setBorderType:NSLineBorder];
	[box setFillColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.5f]];
	[box setBorderColor:[NSColor colorWithCalibratedWhite:0.5f alpha:0.5f]];
	[box setCornerRadius:12.0f];
	[[panel contentView] addSubview:box];

	NSImage *rewindImage = [[NSImage imageNamed:@"rewindImage"] copy];
	[rewindImage setFlipped:isReversed];
	NSSize imageSize = [rewindImage size];
	NSRect imageViewFrame = NSMakeRect(21.0f, 5.0f, imageSize.width, imageSize.height);
	NSImageView *rewindImageView = [[NSImageView alloc] initWithFrame:imageViewFrame];
	[rewindImageView setImage:rewindImage];
	[[box contentView] addSubview:rewindImageView];

	return panel;
}

- (CAKeyframeAnimation *)rewindPanelFadeOutAnimation
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
	animation.duration = 1.0f;
	animation.values = [NSArray arrayWithObjects:
						[NSNumber numberWithFloat:1.0f],
						[NSNumber numberWithFloat:1.0f],
						[NSNumber numberWithFloat:0.0f],
						[NSNumber numberWithFloat:0.0f], nil];
	animation.keyTimes = [NSArray arrayWithObjects:
						  [NSNumber numberWithFloat:0.1f],
						  [NSNumber numberWithFloat:0.3f],
						  [NSNumber numberWithFloat:0.7f],
						  [NSNumber numberWithFloat:animation.duration], nil];

	return animation;
}

- (void)showSearchRewindPanelReverse:(BOOL)isReversed
{
	if (rewindPanel)
		[self closeRewindPanel];

	rewindPanel = [self rewindPanelReverse:isReversed];

	[[[historyController view] window] addChildWindow:rewindPanel ordered:NSWindowAbove];

	CAKeyframeAnimation *alphaAnimation = [self rewindPanelFadeOutAnimation];
    [rewindPanel setAnimations:[NSDictionary dictionaryWithObject:alphaAnimation forKey:@"alphaValue"]];
	[[rewindPanel animator] setAlphaValue:0.0f];

	[self performSelector:@selector(closeRewindPanel) withObject:nil afterDelay:0.7f];
}

@end
