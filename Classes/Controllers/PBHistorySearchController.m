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
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitDefaults.h"
#import "PBCommitList.h"
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

#define kGitXBasicSearchLabel NSLocalizedString(@"Subject, Author, SHA", @"Option in Search menu to search for subject, author or SHA")
#define kGitXPickaxeSearchLabel NSLocalizedString(@"Commit (pickaxe)", @"Option in Search menu to use the pickaxe search")
#define kGitXRegexSearchLabel NSLocalizedString(@"Commit (pickaxe regex)", @"Option in Search menu to use the pickaxe search with regular expressions")
#define kGitXPathSearchLabel NSLocalizedString(@"File path", @"Option in Search menu to search for file paths in the commit")

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
	[self setSearchMode:PBSearchModeForInteger([(NSView*)sender tag])];
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
	if (self.searchMode == PBHistorySearchModeBasic)
		[self startBasicSearch];
	else
		[self startBackgroundSearch];
}

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode
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
	self.searchMode = PBSearchModeForInteger([PBGitDefaults historySearchMode]);

	[self updateUI];

	[commitController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:kGitXSearchArrangedObjectsContext];
}

- (void)dealloc {
	[commitController removeObserver:self forKeyPath:@"arrangedObjects" context:kGitXSearchArrangedObjectsContext];
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
		[historyController selectCommit:commit.OID];
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
		return NSLocalizedString(@"Not found", @"Search count (left of search field): no results");

	if (numberOfMatches == 1)
		return NSLocalizedString(@"1 match", @"Search count (left of search field): exactly one result");

	return [NSString stringWithFormat:
			NSLocalizedString(@"%lu matches", @"Search count (left of search field): number of results"),
			numberOfMatches];
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
	NSMenu *searchMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Search Menu", @"Title of the Search menu.")];
    NSMenuItem *item;

	item = [[NSMenuItem alloc] initWithTitle:kGitXBasicSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:PBHistorySearchModeBasic];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXPickaxeSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:PBHistorySearchModePickaxe];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXRegexSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:PBHistorySearchModeRegex];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:kGitXPathSearchLabel action:@selector(selectSearchMode:) keyEquivalent:@""];
	[item setTarget:self];
    [item setTag:PBHistorySearchModePath];
    [searchMenu addItem:item];

    item = [NSMenuItem separatorItem];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches", @"Searches menu: title of inactive headline item for Recent Searches section") action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu addItem:item];

    item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsMenuItemTag];
    [searchMenu addItem:item];

    item = [NSMenuItem separatorItem];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear Recent Searches", @"Searches menu: title of clear recent searches item") action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldClearRecentsMenuItemTag];
    [searchMenu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Recent Searches", @"Searches menu: title of dummy item displayed in recent searches section when there are no recent searches") action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldNoRecentsMenuItemTag];
    [searchMenu addItem:item];

    [[searchField cell] setSearchMenuTemplate:searchMenu];
}

- (void)updateSearchMenuState
{
	NSMenu *searchMenu = [[searchField cell] searchMenuTemplate];
	if (!searchMenu)
		return;

	[self updateSearchModeMenuItemWithTag:PBHistorySearchModeBasic inMenu:searchMenu];
	[self updateSearchModeMenuItemWithTag:PBHistorySearchModePickaxe inMenu:searchMenu];
	[self updateSearchModeMenuItemWithTag:PBHistorySearchModeRegex inMenu:searchMenu];
	[self updateSearchModeMenuItemWithTag:PBHistorySearchModePath inMenu:searchMenu];

    [[searchField cell] setSearchMenuTemplate:searchMenu];

	[PBGitDefaults setHistorySearchMode:searchMode];
}

- (void) updateSearchModeMenuItemWithTag:(PBHistorySearchMode)menuItemSearchMode inMenu:(NSMenu *) searchMenu {
	NSMenuItem * menuItem = [searchMenu itemWithTag:menuItemSearchMode];
	[menuItem setState:(searchMode == menuItemSearchMode) ? NSOnState : NSOffState];
}

- (void)updateSearchPlaceholderString
{
	switch (self.searchMode) {
		case PBHistorySearchModePickaxe:
			[[searchField cell] setPlaceholderString:kGitXPickaxeSearchLabel];
			break;
		case PBHistorySearchModeRegex:
			[[searchField cell] setPlaceholderString:kGitXRegexSearchLabel];
			break;
		case PBHistorySearchModePath:
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
	searchMode = mode;
	[PBGitDefaults setHistorySearchMode:mode];

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
	NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"subject CONTAINS[cd] %@ OR author CONTAINS[cd] %@ OR SHA BEGINSWITH[c] %@", searchString, searchString, searchString];

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
		case PBHistorySearchModeRegex:
			[searchArguments addObject:@"--pickaxe-regex"];
		case PBHistorySearchModePickaxe:
			[searchArguments addObject:[NSString stringWithFormat:@"-S%@", searchString]];
			break;
		case PBHistorySearchModePath:
			[searchArguments addObject:@"--"];
			[searchArguments addObjectsFromArray:[searchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
			break;
		default:
			return;
	}

	backgroundSearchTask = [historyController.repository taskWithArguments:searchArguments];
	[backgroundSearchTask performTaskWithCompletionHandler:^(NSData * _Nullable readData, NSError * _Nullable error) {
		if (!readData) {
			[historyController.windowController showErrorSheet:error];
			return;
		}
		[self parseBackgroundSearchResults:readData];
	}];

	[self startProgressIndicator];
}

- (void)parseBackgroundSearchResults:(NSData *)data
{
	backgroundSearchTask = nil;

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
		return [matches containsObject:commit.OID];
	}];

	results = indexes;
	[self clearProgressIndicator];
	[self updateSelectedResult];
}



#pragma mark -
#pragma mark Rewind Panel

#define kRewindPanelSize 125.0f
#define kRewindPanelImageViewTag 1234

- (void)closeRewindPanel
{
	[[[historyController view] window] removeChildWindow:rewindPanel];
	[rewindPanel close];
	rewindPanel = nil;
}

- (NSPanel *)rewindPanel
{
	// Update the panel frame in case the window was resized
	NSRect windowFrame = [[[historyController view] window] frame];
	NSRect historyFrame = [historyController.view.window.contentView convertRect:historyController.view.frame
																		fromView:historyController.view];
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

	NSImage *rewindImage = [NSImage imageNamed:@"rewindImage"];
	NSSize imageSize = [rewindImage size];
	NSRect imageViewFrame = NSMakeRect(21.0f, 5.0f, imageSize.width, imageSize.height);
	NSImageView *rewindImageView = [[NSImageView alloc] initWithFrame:imageViewFrame];
	[rewindImageView setTag:kRewindPanelImageViewTag];
	[[box contentView] addSubview:rewindImageView];

	return panel;
}

- (CAKeyframeAnimation *)rewindPanelFadeOutAnimation
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
	animation.duration = 1.0f;
	animation.values = @[@1.0f, @1.0f, @0.0f, @0.0f];
	animation.keyTimes = @[@0.1f, @0.3f, @0.7f, [NSNumber numberWithDouble:animation.duration]];
	return animation;
}

- (void)showSearchRewindPanelReverse:(BOOL)isReversed
{
	if (rewindPanel != nil) {
		// Panel still open, cancel the upcoming close
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(closeRewindPanel) object:nil];
	} else {
		// The panel is already closed, create a new one
		rewindPanel = [self rewindPanel];

		[[[historyController view] window] addChildWindow:rewindPanel ordered:NSWindowAbove];
	}

	// Setup our wrap-results image depending on the direction we wrapped
	NSImage *rewindImage = [NSImage imageNamed:@"rewindImage"];
	NSImage *reversedRewindImage = [NSImage imageWithSize:rewindImage.size
												  flipped:isReversed
										   drawingHandler:^BOOL(NSRect destRect) {
		[rewindImage drawInRect:destRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		return YES;
	}];
	NSImageView *rewindImageView = [rewindPanel.contentView viewWithTag:kRewindPanelImageViewTag];
	[rewindImageView setImage:reversedRewindImage];

	// Perform the fade-out animation
	[rewindPanel setAlphaValue:1.0f];

	CAKeyframeAnimation *alphaAnimation = [self rewindPanelFadeOutAnimation];
	[rewindPanel setAnimations:[NSDictionary dictionaryWithObject:alphaAnimation forKey:@"alphaValue"]];
	[[rewindPanel animator] setAlphaValue:0.0f];

	[self performSelector:@selector(closeRewindPanel) withObject:nil afterDelay:0.7f];
}

@end
