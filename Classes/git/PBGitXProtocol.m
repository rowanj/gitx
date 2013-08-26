//
//  PBGitXProtocol.m
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitXProtocol.h"


@implementation PBGitXProtocol

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	return [[[[request URL] scheme] lowercaseString] isEqualToString:@"gitx"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

-(void)startLoading
{
    NSURL *url = [[self request] URL];
    
    if ([[url host] isEqualToString:@"custom.css"]) {
        [self startLoadingCustomCSS];
        return;
    }
    
	PBGitRepository *repo = [[self request] repository];
    NSString * commit = [url host];
    NSString * filepath = [url path];
	if (repo) {
        [self startLoadingGitFile:filepath atCommit:commit withRepository:repo];
        return;
    }
    
    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
}

- (void)startLoadingCustomCSS
{
    NSString * filepath = @"~/.gitxcustom.css";
    NSFileHandle * filehandle = [NSFileHandle fileHandleForReadingAtPath:[filepath stringByExpandingTildeInPath]];
    [self startLoadingToEndOfFileHandle:filehandle];
}

- (void)startLoadingGitFile:(NSString *)filepath atCommit:(NSString *)commit withRepository:(PBGitRepository *)repo
{
    NSString *specifier = [NSString stringWithFormat:@"%@:%@", commit, [filepath substringFromIndex:1]];
	NSFileHandle * filehandle = [repo handleInWorkDirForArguments:[NSArray arrayWithObjects:@"cat-file", @"blob", specifier, nil]];
    [self startLoadingToEndOfFileHandle:filehandle];
}

- (void)startLoadingToEndOfFileHandle:(NSFileHandle *)handle_
{
    if (handle_ == nil) {
        [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
        return;
    }
    
    handle = handle_;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishFileLoad:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle];
	[handle readToEndOfFileInBackgroundAndNotify];

    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[[self request] URL]
														MIMEType:nil
										   expectedContentLength:-1
												textEncodingName:nil];

    [[self client] URLProtocol:self
			didReceiveResponse:response
			cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void) didFinishFileLoad:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void) stopLoading
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
