//
//  PBHistorySearchController.h
//  GitX
//
//  Created by Nathan Kinsinger on 8/21/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef enum historySearchModes {
	kGitXBasicSeachMode = 1,
	kGitXPickaxeSearchMode,
	kGitXRegexSearchMode,
	kGitXPathSearchMode,
	kGitXMaxSearchMode    // always keep this item last
} PBHistorySearchMode;

@class PBGitHistoryController;


@interface PBHistorySearchController : NSObject {
	PBHistorySearchMode searchMode;
	NSIndexSet *results;
	NSTimer *searchTimer;
	NSTask *backgroundSearchTask;
	NSPanel *rewindPanel;
}

@property (weak) IBOutlet PBGitHistoryController *historyController;
@property (weak) IBOutlet NSArrayController *commitController;

@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSSegmentedControl *stepper;
@property (weak) IBOutlet NSTextField *numberOfMatchesField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property PBHistorySearchMode searchMode;


- (BOOL)isRowInSearchResults:(NSInteger)rowIndex;
- (BOOL)hasSearchResults;

- (void)selectSearchMode:(id)sender;

- (void)selectNextResult;
- (void)selectPreviousResult;
- (IBAction)stepperPressed:(id)sender;

- (void)clearSearch;
- (IBAction)updateSearch:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

@end
