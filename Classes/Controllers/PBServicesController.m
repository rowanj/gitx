//
//  PBServicesController.m
//  GitX
//
//  Created by Pieter de Bie on 10/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBServicesController.h"
#import "PBGitRepositoryDocument.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"

@implementation PBServicesController

- (NSString *)completeSHA1For:(NSString *)sha error:(NSString **)error
{
	NSArray *documents = [[NSApplication sharedApplication] orderedDocuments];
	for (PBGitRepositoryDocument *doc in documents)
	{
		NSError *error = nil;
		NSString *s = [doc.repository outputOfTaskWithArguments:@[@"log", @"-1", @"--pretty=format:%h (%s)", sha] error:&error];
		if (s) {
			return s;
		}
	}

	if (error) *error = @"Unable to resolve SHA in opened repositories";
	return nil;
}

- (NSString *)runNameRevFor:(NSString *)s error:(NSString **)errorStr
{
	NSArray *repositories = [[NSApplication sharedApplication] orderedDocuments];
	if ([repositories count] == 0)
		return s;
	PBGitRepositoryDocument *doc = [repositories objectAtIndex:0];

	NSError *error = nil;
	PBTask *task = [doc.repository taskWithArguments:@[]];
	task.standardInputData = [s dataUsingEncoding:NSUTF8StringEncoding];
	BOOL success = [task launchTask:&error];

	if (success) {
		return task.standardOutputString;
	} else {
		PBLogError(error);
	}

	if (errorStr) *errorStr = @"Unable to resolve SHA in opened repositories";
	return nil;
}

- (void)completeSha:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	NSArray *types = [pboard types];
	if (![types containsObject:NSStringPboardType])
	{
		*error = @"Could not get data";
		return;
	}

	NSString *s = [pboard stringForType:NSStringPboardType];
	if ([s rangeOfString:@" "].location == NSNotFound)
		s = [self completeSHA1For:s error:error];
	else
		s = [self runNameRevFor:s error:error];

	if (!s) return;

	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pboard setString:s forType:NSStringPboardType];
}
@end
