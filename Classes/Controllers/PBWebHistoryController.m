//
//  PBWebGitController.m
//  GitTest
//
//  Created by Pieter de Bie on 14-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebHistoryController.h"
#import "PBGitDefaults.h"
#import <ObjectiveGit/GTConfiguration.h>
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"
#import <stdatomic.h>

@interface PBWebHistoryController ()
@property (nonatomic) atomic_ulong commitSummaryGeneration;
@end

@implementation PBWebHistoryController

@synthesize diff;

- (void) awakeFromNib
{
	startFile = @"history";
	repository = historyController.repository;
	[super awakeFromNib];
	[historyController addObserver:self forKeyPath:@"webCommits" options:0 context:@"ChangedCommit"];
}

- (void)closeView
{
	[[self script] setValue:nil forKey:@"commit"];
	[historyController removeObserver:self forKeyPath:@"webCommits"];

	[super closeView];
}

- (void) didLoad
{
	currentOID = nil;
	[self changeContentTo:historyController.webCommits];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(__bridge NSString *)context isEqualToString: @"ChangedCommit"])
		[self changeContentTo:historyController.webCommits];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) changeContentTo:(NSArray<PBGitCommit *> *)commits
{
	if (commits == nil || commits.count == 0 || !finishedLoading) {
		return;
	}
	
	if (commits.count == 1) {
		[self changeContentToCommit:commits.firstObject];
	}
	else {
		[self changeContentToMultipleSelectionMessage];
	}
}

- (void) changeContentToMultipleSelectionMessage {
	NSArray *arguments = @[
			@[NSLocalizedString(@"Multiple commits are selected.", @"Multiple selection Message: Title"),
			  NSLocalizedString(@"Use the Copy command to copy their information.", @"Multiple selection Message: Copy Command"),
			  NSLocalizedString(@"Or select a single commit to see its diff.", @"Multiple selection Message: Diff Hint")
			  ]];
	[[self script] callWebScriptMethod:@"showMultipleSelectionMessage" withArguments:arguments];
}

static NSString *deltaTypeName(GTDeltaType t) {
	switch (t) {
		case GTDeltaTypeUnmodified: return @"unmodified";
		case GTDeltaTypeAdded: return @"added";
		case GTDeltaTypeDeleted: return @"removed";
		case GTDeltaTypeModified: return @"modified";
		case GTDeltaTypeRenamed: return @"renamed";
		case GTDeltaTypeCopied: return @"copied";
		case GTDeltaTypeIgnored: return @"ignored";
		case GTDeltaTypeUntracked: return @"untracked";
		case GTDeltaTypeTypeChange: return @"type changed";
		case GTDeltaTypeUnreadable: return @"unreadable";
		case GTDeltaTypeConflicted: return @"conflicted";
	}
}

static NSDictionary *loadCommitSummary(GTRepository *repo, GTCommit *commit, BOOL (^isCanceled)());

// A GTDiffDelta's GTDiffFile does not always set the file size. See `git_diff_get_delta`.
static NSUInteger reallyGetFileSize(GTRepository *repo, GTDiffFile *file) {
	GTObjectDatabase *odb = [repo objectDatabaseWithError:nil];
	if (!odb) return 0;
	size_t size = 0;
	git_otype otype;
	if (git_odb_read_header(&size, &otype, odb.git_odb, file.OID.git_oid) != 0) {
		return 0;
	}
	return size;
}

- (void) changeContentToCommit:(PBGitCommit *)commit
{
	// The sha is the same, but refs may have changed. reload it lazy
	if ([currentOID isEqual:commit.OID])
	{
		[[self script] callWebScriptMethod:@"reload" withArguments: nil];
		return;
	}

	NSArray *arguments = @[commit, [[[historyController repository] headRef] simpleRef]];
	id scriptResult = [[self script] callWebScriptMethod:@"loadCommit" withArguments: arguments];
	if (!scriptResult) {
		// the web view is not really ready for scripting???
		[self performSelector:_cmd withObject:commit afterDelay:0.05];
		return;
	}
	currentOID = commit.OID;

	unsigned long gen = atomic_fetch_add(&_commitSummaryGeneration, 1) + 1;

	// Open a new repo instance for the background queue
	NSError *err = nil;
	GTRepository *repo =
	    [GTRepository repositoryWithURL:[repository gtRepo].gitDirectoryURL error:&err];
	if (!repo) {
		NSLog(@"Failed to open repository: %@", err);
		return;
	}
	GTCommit *queueCommit = [repo lookUpObjectByOID:commit.OID error:&err];
	if (!queueCommit) {
		NSLog(@"Failed to find commit: %@", err);
		return;
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSDictionary *summary = loadCommitSummary(repo, queueCommit, ^BOOL {
			return gen != atomic_load(&_commitSummaryGeneration);
		});
		if (!summary) return;
		NSError *err = nil;
		NSString *summaryJSON =
		    [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:summary
		                                                                   options:0
		                                                                     error:&err]
		                          encoding:NSUTF8StringEncoding];
		if (!summaryJSON) {
			NSLog(@"Commit summary JSON error: %@", err);
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[self commitSummaryLoaded:summaryJSON forOID:commit.OID];
		});
	});
}

static NSDictionary *loadCommitSummary(GTRepository *repo, GTCommit *commit, BOOL (^isCanceled)()) {
	if (isCanceled()) return nil;
	GTDiffFindOptionsFlags flags = GTDiffFindOptionsFlagsFindRenames;
	if (![PBGitDefaults showWhitespaceDifferences]) {
		flags |= GTDiffFindOptionsFlagsIgnoreWhitespace;
	}
	NSError *err = nil;
	GTDiff *d = [GTDiff diffOldTree:commit.parents.firstObject.tree
	                    withNewTree:commit.tree
	                   inRepository:repo
							options:@{}
	                          error:&err];

	if (!d) {
		NSLog(@"Commit summary diff error: %@", err);
		return nil;
	}

	// Rewrite the diff to display moved files.
	[d findSimilarWithOptions:@{GTDiffFindOptionsFlagsKey:@(flags)}];

	if (isCanceled()) return nil;
	NSMutableArray<NSDictionary<NSString *, NSObject *> *> *fileDeltas = [NSMutableArray array];
	NSMutableString *fullDiff = [NSMutableString string];
	[d enumerateDeltasUsingBlock:^(GTDiffDelta *_Nonnull delta, BOOL *_Nonnull stop) {
		if (isCanceled()) {
			*stop = YES;
			return;
		}
		NSUInteger numLinesAdded = 0;
		NSUInteger numLinesRemoved = 0;
		NSError *err = nil;
		GTDiffPatch *patch = [delta generatePatch:&err];
		if (isCanceled()) {
			*stop = YES;
			return;
		}
		if (patch) {
			numLinesAdded = patch.addedLinesCount;
			numLinesRemoved = patch.deletedLinesCount;
			NSData *patchData = patch.patchData;
			if (patchData) {
				NSString *patchString =
				    [[NSString alloc] initWithData:patchData
				                          encoding:NSUTF8StringEncoding];
				if (!patchString) {
					patchString =
					    [[NSString alloc] initWithData:patchData
					                          encoding:NSISOLatin1StringEncoding];
				}
				if (patchString) {
					[fullDiff appendString:patchString];
				}
			}
			// Use the patch's delta as it may have loaded more file sizes.
			delta = patch.delta;
		} else {
			NSLog(@"generatePatch error: %@", err);
		}
		GTDiffFile *oldFile = delta.oldFile;
		GTDiffFile *newFile = delta.newFile;
		NSUInteger oldFileSize = oldFile.size;
		NSUInteger newFileSize = newFile.size;
		if (oldFileSize == 0 && (oldFile.flags & GIT_DIFF_FLAG_EXISTS)) {
			oldFileSize = reallyGetFileSize(repo, newFile);
		}
		if (newFileSize == 0 && (newFile.flags & GIT_DIFF_FLAG_EXISTS)) {
			newFileSize = reallyGetFileSize(repo, newFile);
		}
		[fileDeltas addObject:@{
			@"filename" : newFile.path,
			@"oldFilename" : oldFile.path,
			@"newFilename" : newFile.path,
			@"changeType" : deltaTypeName(delta.type),
			@"oldFileSize" : @(oldFileSize),
			@"newFileSize" : @(newFileSize),
			@"numLinesAdded" : @(numLinesAdded),
			@"numLinesRemoved" : @(numLinesRemoved),
			@"binary" : [NSNumber numberWithBool:(delta.flags & GTDiffFileFlagBinary) != 0],
		}];
	}];
	if (isCanceled()) return nil;
	return @{
		@"filesInfo" : fileDeltas,
		@"fullDiff" : fullDiff,
	};
}

- (void)commitSummaryLoaded:(NSString *)summaryJSON forOID:(GTOID *)summaryOID
{
	if (![currentOID isEqual:summaryOID]) {
		// a different summary finished loading late
		return;
	}

	[self.view.windowScriptObject callWebScriptMethod:@"loadCommitDiff" withArguments:@[summaryJSON]];
}

- (void)selectCommit:(NSString *)sha
{
	[historyController selectCommit: [GTOID oidWithSHA: sha]];
}

- (void) sendKey: (NSString*) key
{
	id script = self.view.windowScriptObject;
	[script callWebScriptMethod:@"handleKeyFromCocoa" withArguments: [NSArray arrayWithObject:key]];
}

- (void) copySource
{
	NSString *source = [(DOMHTMLElement *)self.view.mainFrame.DOMDocument.documentElement outerHTML];
	NSPasteboard *a =[NSPasteboard generalPasteboard];
	[a declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[a setString:source forType: NSStringPboardType];
}

- (NSArray *)	   webView:(WebView *)sender
contextMenuItemsForElement:(NSDictionary *)element
		  defaultMenuItems:(NSArray *)defaultMenuItems
{
	DOMNode *node = [element valueForKey:@"WebElementDOMNode"];

	while (node) {
		// Every ref has a class name of 'refs' and some other class. We check on that to see if we pressed on a ref.
		if ([[node className] hasPrefix:@"refs "]) {
			NSString *selectedRefString = [[[node childNodes] item:0] textContent];
			for (PBGitRef *ref in historyController.webCommits.firstObject.refs) {
				if ([[ref shortName] isEqualToString:selectedRefString])
					return [contextMenuDelegate menuItemsForRef:ref];
			}
			NSLog(@"Could not find selected ref!");
			return defaultMenuItems;
		}
		if ([node hasAttributes] && [[node attributes] getNamedItem:@"representedFile"])
			return [historyController menuItemsForPaths:[NSArray arrayWithObject:[[[node attributes] getNamedItem:@"representedFile"] nodeValue]]];
        else if ([[node class] isEqual:[DOMHTMLImageElement class]]) {
            // Copy Image is the only menu item that makes sense here since we don't need
			// to download the image or open it in a new window (besides with the
			// current implementation these two entries can crash GitX anyway)
			for (NSMenuItem *item in defaultMenuItems)
				if ([item tag] == WebMenuItemTagCopyImageToClipboard)
					return [NSArray arrayWithObject:item];
			return nil;
        }

		node = [node parentNode];
	}

	return defaultMenuItems;
}


// Open external links in the default browser
-   (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
   		  request:(NSURLRequest *)request
     newFrameName:(NSString *)frameName
 decisionListener:(id < WebPolicyDecisionListener >)listener
{
	[[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

- getConfig:(NSString *)key
{
	NSError *error = nil;
    GTConfiguration* config = [historyController.repository.gtRepo configurationWithError:&error];
	return [config stringForKey:key];
}


- (void) preferencesChanged
{
	[[self script] callWebScriptMethod:@"enableFeatures" withArguments:nil];
}

@end
