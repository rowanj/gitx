//
//  PBWebController.m
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebController.h"
#import "PBGitRepository.h"
#import "PBGitXProtocol.h"
#import "PBGitDefaults.h"

#include <SystemConfiguration/SCNetworkReachability.h>

@interface PBWebController()
- (void)preferencesChangedWithNotification:(NSNotification *)theNotification;
@end

@implementation PBWebController

@synthesize startFile, repository;

- (void) awakeFromNib
{
	NSString *path = [NSString stringWithFormat:@"html/views/%@", startFile];
	NSString* file = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
	NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:file]];
	callbacks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory) valueOptions:(NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory)];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
	       selector:@selector(preferencesChangedWithNotification:)
		   name:NSUserDefaultsDidChangeNotification
		 object:nil];

	finishedLoading = NO;
	[view setUIDelegate:self];
	[view setFrameLoadDelegate:self];
	[view setResourceLoadDelegate:self];
	[[view mainFrame] loadRequest:request];
}

- (WebScriptObject *) script
{
	return [view windowScriptObject];
}

- (void)closeView
{
	if (view) {
		[[self script] setValue:nil forKey:@"Controller"];
		[view close];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

# pragma mark Delegate methods

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
	id script = [view windowScriptObject];
	[script setValue: self forKey:@"Controller"];
}

- (void) webView:(id) v didFinishLoadForFrame:(id) frame
{
	finishedLoading = YES;
	if ([self respondsToSelector:@selector(didLoad)])
		[self performSelector:@selector(didLoad)];
}

- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)dictionary
{
	NSLog(@"Error from webkit: %@", dictionary);
}

- (NSURLRequest *)webView:(WebView *)sender
                 resource:(id)identifier
          willSendRequest:(NSURLRequest *)request
         redirectResponse:(NSURLResponse *)redirectResponse
           fromDataSource:(WebDataSource *)dataSource
{
	if (!self.repository)
		return request;

	// TODO: Change this to canInitWithRequest
	if ([[[[request URL] scheme] lowercaseString] isEqualToString:@"gitx"]) {
		NSMutableURLRequest *newRequest = [request mutableCopy];
		[newRequest setRepository:self.repository];
		return newRequest;
	}

	return request;
}

- (void)webView:(WebView *)sender
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
		  frame:(WebFrame *)frame
decisionListener:(id <WebPolicyDecisionListener>)listener
{
	NSString* scheme = [[request URL] scheme];
	if ([scheme compare:@"http"] == NSOrderedSame ||
		[scheme compare:@"https"] == NSOrderedSame)
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
	else
	{
		[listener use];
	}
}

- (NSUInteger)webView:(WebView *)webView
dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
    return NSDragOperationNone;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}

#pragma mark Functions to be used from JavaScript

- (void) log: (NSString*) logMessage
{
	NSLog(@"%@", logMessage);
}

- (BOOL) isReachable:(NSString *)hostname
{
    SCNetworkReachabilityRef target;
    SCNetworkConnectionFlags flags = 0;
    Boolean reachable;
    target = SCNetworkReachabilityCreateWithName(NULL, [hostname cStringUsingEncoding:NSASCIIStringEncoding]);
    reachable = SCNetworkReachabilityGetFlags(target, &flags);
	CFRelease(target);

	if (!reachable)
		return FALSE;

	// If a connection is required, then it's not reachable
	if (flags & (kSCNetworkFlagsConnectionRequired | kSCNetworkFlagsConnectionAutomatic | kSCNetworkFlagsInterventionRequired))
		return FALSE;

	return flags > 0;
}

- (BOOL) isFeatureEnabled:(NSString *)feature
{
	if([feature isEqualToString:@"gravatar"])
		return [PBGitDefaults isGravatarEnabled];
	else if([feature isEqualToString:@"gist"])
		return [PBGitDefaults isGistEnabled];
	else if([feature isEqualToString:@"confirmGist"])
		return [PBGitDefaults confirmPublicGists];
	else if([feature isEqualToString:@"publicGist"])
		return [PBGitDefaults isGistPublic];
	else
		return YES;
}

#pragma mark Using async function from JS

- (void) runCommand:(WebScriptObject *)arguments inRepository:(PBGitRepository *)repo callBack:(WebScriptObject *)callBack
{
	// The JS bridge does not handle JS Arrays, even though the docs say it does. So, we convert it ourselves.
	int length = [[arguments valueForKey:@"length"] intValue];
	NSMutableArray *realArguments = [NSMutableArray arrayWithCapacity:length];
	int i = 0;
	for (i = 0; i < length; i++)
		[realArguments addObject:[arguments webScriptValueAtIndex:i]];

	NSFileHandle *handle = [repo handleInWorkDirForArguments:realArguments];
	[callbacks setObject:callBack forKey:handle];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(JSRunCommandDone:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}

- (void) returnCallBackForObject:(id)object withData:(id)data
{
	WebScriptObject *a = [callbacks objectForKey: object];
	if (!a) {
		NSLog(@"Could not find a callback for object: %@", object);
		return;
	}

	[callbacks removeObjectForKey:object];
	[a callWebScriptMethod:@"call" withArguments:[NSArray arrayWithObjects:@"", data, nil]];
}

- (void) threadFinished:(NSArray *)arguments
{
	[self returnCallBackForObject:[arguments objectAtIndex:0] withData:[arguments objectAtIndex:1]];
}

- (void) JSRunCommandDone:(NSNotification *)notification
{
	NSString *data = [[NSString alloc] initWithData:[[notification userInfo] valueForKey:NSFileHandleNotificationDataItem] encoding:NSUTF8StringEncoding];
	[self returnCallBackForObject:[notification object] withData:data];
}

- (void) preferencesChanged
{
}

- (void)preferencesChangedWithNotification:(NSNotification *)theNotification
{
	[self preferencesChanged];
}

@end
