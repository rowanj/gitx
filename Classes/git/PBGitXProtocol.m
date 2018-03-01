//
//  PBGitXProtocol.m
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitXProtocol.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"

@interface PBGitXProtocol () {
	PBTask *_task;
}
@end

@implementation PBGitXProtocol

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	NSString *URLScheme = request.URL.scheme;
	if ([[URLScheme lowercaseString] isEqualToString:@"gitx"])
		return YES;

	return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

-(void)startLoading
{
    NSURL *url = [[self request] URL];
	PBGitRepository *repo = [[self request] repository];

	if (!repo) {
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
		return;
    }

	NSString *specifier = [NSString stringWithFormat:@"%@:%@", [url host], [[url path] substringFromIndex:1]];
	_task = [repo taskWithArguments:@[@"cat-file", @"blob", specifier]];
	[_task performTaskWithCompletionHandler:^(NSData *readData, NSError *error) {
		if (error) {
			[[self client] URLProtocol:self didFailWithError:error];
			return;
		}

		[[self client] URLProtocol:self didLoadData:readData];
		[[self client] URLProtocolDidFinishLoading:self];
	}];

    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[[self request] URL]
														MIMEType:nil
										   expectedContentLength:-1
												textEncodingName:nil];

    [[self client] URLProtocol:self
			didReceiveResponse:response
			cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void) stopLoading
{
	[_task terminate];
}

@end

@implementation NSURLRequest (PBGitXProtocol)
@dynamic repository;

- (PBGitRepository *) repository
{
	return [NSURLProtocol propertyForKey:@"PBGitRepository" inRequest:self];
}
@end

@implementation NSMutableURLRequest (PBGitXProtocol)
@dynamic repository;

- (void) setRepository:(PBGitRepository *)repository
{
	[NSURLProtocol setProperty:repository forKey:@"PBGitRepository" inRequest:self];
}

@end
