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

@implementation PBWebHistoryController

@synthesize diff;

- (void) awakeFromNib
{
	startFile = @"history";
	repository = historyController.repository;
	[super awakeFromNib];
	[historyController addObserver:self forKeyPath:@"webCommit" options:0 context:@"ChangedCommit"];
}

- (void)closeView
{
	[[self script] setValue:nil forKey:@"commit"];
	[historyController removeObserver:self forKeyPath:@"webCommit"];

	[super closeView];
}

- (void) didLoad
{
	currentSha = nil;
	[self changeContentTo: historyController.webCommit];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(__bridge NSString *)context isEqualToString: @"ChangedCommit"])
		[self changeContentTo: historyController.webCommit];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) changeContentTo: (PBGitCommit *) content
{
	if (content == nil || !finishedLoading)
		return;

	// The sha is the same, but refs may have changed.. reload it lazy
	if ([currentSha isEqual:[content sha]])
	{
		[[self script] callWebScriptMethod:@"reload" withArguments: nil];
		return;
	}

	NSArray *arguments = [NSArray arrayWithObjects:content, [[[historyController repository] headRef] simpleRef], nil];
	id scriptResult = [[self script] callWebScriptMethod:@"loadCommit" withArguments: arguments];
	if (!scriptResult) {
		// the web view is not really ready for scripting???
		[self performSelector:_cmd withObject:content afterDelay:0.05];
		return;
	}
	currentSha = [content sha];

	// Now we load the extended details. We used to do this in a separate thread,
	// but this caused some funny behaviour because NSTask's and NSThread's don't really
	// like each other. Instead, just do it async.

	NSMutableArray *taskArguments = [NSMutableArray arrayWithObjects:@"show", @"--pretty=raw", @"-M", @"--no-color", [currentSha SHA], nil];
	if (![PBGitDefaults showWhitespaceDifferences])
		[taskArguments insertObject:@"-w" atIndex:1];

	NSFileHandle *handle = [repository handleForArguments:taskArguments];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	// Remove notification, in case we have another one running
	[nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
	[nc addObserver:self selector:@selector(commitDetailsLoaded:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}

- (void)commitDetailsLoaded:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];

	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	if (!data)
		return;

	NSString *details = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!details)
		details = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

	if (!details)
		return;

	[[view windowScriptObject] callWebScriptMethod:@"loadCommitDetails" withArguments:[NSArray arrayWithObject:details]];
}

- (void)selectCommit:(NSString *)sha
{
	[historyController selectCommit: [GTOID oidWithSHA: sha]];
}

- (void) sendKey: (NSString*) key
{
	id script = [view windowScriptObject];
	[script callWebScriptMethod:@"handleKeyFromCocoa" withArguments: [NSArray arrayWithObject:key]];
}

- (void) copySource
{
	NSString *source = [(DOMHTMLElement *)[[[view mainFrame] DOMDocument] documentElement] outerHTML];
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
			for (PBGitRef *ref in historyController.webCommit.refs)
			{
				if ([[ref shortName] isEqualToString:selectedRefString])
					return [contextMenuDelegate menuItemsForRef:ref];
			}
			NSLog(@"Could not find selected ref!");
			return defaultMenuItems;
		}
		if ([node hasAttributes] && [[node attributes] getNamedItem:@"representedFile"])
			return [historyController menuItemsForPaths:[NSArray arrayWithObject:[[[node attributes] getNamedItem:@"representedFile"] value]]];
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
