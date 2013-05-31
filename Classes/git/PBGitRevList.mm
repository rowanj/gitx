//
//  PBGitRevList.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevList.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitGrapher.h"
#import "PBGitRevSpecifier.h"
#import "PBEasyPipe.h"
#import "PBGitBinary.h"

#include <ext/stdio_filebuf.h>
#include <iostream>
#include <string>
#include <map>

using namespace std;


@interface PBGitRevList ()

@property (assign) BOOL isParsing;

@end


#define kRevListThreadKey @"thread"
#define kRevListRevisionsKey @"revisions"


@implementation PBGitRevList

@synthesize commits;
@synthesize isParsing;


- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph
{
	repository = repo;
	isGraphing = graph;
	currentRev = [rev copy];

	return self;
}


- (void) loadRevisons
{
	[parseThread cancel];

	parseThread = [[NSThread alloc] initWithTarget:self selector:@selector(walkRevisionListWithSpecifier:) object:currentRev];
	self.isParsing = YES;
	resetCommits = YES;
	[parseThread start];
}


- (void)cancel
{
	[parseThread cancel];
}


- (void) finishedParsing
{
	self.isParsing = NO;
}


- (void) updateCommits:(NSDictionary *)update
{
	if ([update objectForKey:kRevListThreadKey] != parseThread)
		return;

	NSArray *revisions = [update objectForKey:kRevListRevisionsKey];
	if (!revisions || [revisions count] == 0)
		return;

	if (resetCommits) {
		self.commits = [NSMutableArray array];
		resetCommits = NO;
	}

	NSRange range = NSMakeRange([commits count], [revisions count]);
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:range];

	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
	[commits addObjectsFromArray:revisions];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
}


- (void) walkRevisionListWithSpecifier:(PBGitRevSpecifier*)rev
{
	@autoreleasepool {
		NSDate *start = [NSDate date];
		NSDate *lastUpdate = [NSDate date];
		NSMutableArray *revisions = [NSMutableArray array];
		PBGitGrapher *g = [[PBGitGrapher alloc] initWithRepository:repository];
		std::map<string, NSStringEncoding> encodingMap;
		NSThread *currentThread = [NSThread currentThread];
		
		NSString *formatString = @"--pretty=format:%H\03%e\03%aN\03%cN\03%s\03%P\03%at";
		BOOL showSign = [rev hasLeftRight];
		
		if (showSign)
			formatString = [formatString stringByAppendingString:@"\03%m"];
		
		NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"log",
									 @"-z",
									 @"--topo-order",
									 @"--children",
									 @"--encoding=UTF-8",
									 formatString, nil];
		
		if (!rev)
			[arguments addObject:@"HEAD"];
		else
			[arguments addObjectsFromArray:[rev parameters]];
		
		NSString *directory = rev.workingDirectory ? rev.workingDirectory.path : repository.fileURL.path;
		NSTask *task = [PBEasyPipe taskForCommand:[PBGitBinary path] withArgs:arguments inDir:directory];
		[task launch];
		NSFileHandle *handle = [task.standardOutput fileHandleForReading];
		
		int fd = [handle fileDescriptor];
		__gnu_cxx::stdio_filebuf<char> buf(fd, std::ios::in);
		std::istream stream(&buf);
		
		int num = 0;
		while (true) {
			if ([currentThread isCancelled])
				break;
			
			string sha;
			if (!getline(stream, sha, '\3'))
				break;
			
			// From now on, 1.2 seconds
			string encoding_str;
			getline(stream, encoding_str, '\3');
			NSStringEncoding encoding = NSUTF8StringEncoding;
			if (encoding_str.length())
			{
				if (encodingMap.find(encoding_str) != encodingMap.end()) {
					encoding = encodingMap[encoding_str];
				} else {
					encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)[NSString stringWithUTF8String:encoding_str.c_str()]));
					encodingMap[encoding_str] = encoding;
				}
			}
			
			git_oid oid;
			git_oid_fromstr(&oid, sha.c_str());
			PBGitCommit *newCommit = [PBGitCommit commitWithRepository:repository andSha:[PBGitSHA shaWithOID:oid]];
			
			string author;
			getline(stream, author, '\3');
			
			string committer;
			getline(stream, committer, '\3');
			
			string subject;
			getline(stream, subject, '\3');
			
			string parentString;
			getline(stream, parentString, '\3');
			if (parentString.size() != 0)
			{
				if (((parentString.size() + 1) % 41) != 0) {
					NSLog(@"invalid parents: %zu", parentString.size());
					continue;
				}
				int nParents = (parentString.size() + 1) / 41;
				NSMutableArray *parents = [NSMutableArray arrayWithCapacity:nParents];
				int parentIndex;
				for (parentIndex = 0; parentIndex < nParents; ++parentIndex) {
					PBGitSHA *parentSHA = [PBGitSHA shaWithCString:parentString.substr(parentIndex * 41, 40).c_str()];
					if (parentSHA) {
						[parents addObject:parentSHA];
					} else {
						NSLog(@"Nil parent (orphan object) in parents \"%s\"", parentString.c_str());
					}
				}
				
				[newCommit setParents:parents];
			}
			
			int time;
			stream >> time;
			
			[newCommit setSubject:[NSString stringWithCString:subject.c_str() encoding:encoding]];
			[newCommit setAuthor:[NSString stringWithCString:author.c_str() encoding:encoding]];
			[newCommit setCommitter:[NSString stringWithCString:committer.c_str() encoding:encoding]];
			[newCommit setTimestamp:time];
			
			if (showSign)
			{
				char c;
				stream >> c; // Remove separator
				stream >> c;
				if (c != '>' && c != '<' && c != '^' && c != '-')
					NSLog(@"Error loading commits: sign not correct");
				[newCommit setSign: c];
			}
			
			char c;
			stream >> c;
			if (c != '\0')
				cout << "Error" << endl;
			
			[revisions addObject: newCommit];
			if (isGraphing)
				[g decorateCommit:newCommit];
			
			if (++num % 100 == 0) {
				if ([[NSDate date] timeIntervalSinceDate:lastUpdate] > 0.1) {
					NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:currentThread, kRevListThreadKey, revisions, kRevListRevisionsKey, nil];
					[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:NO];
					revisions = [NSMutableArray array];
					lastUpdate = [NSDate date];
				}
			}
		}
		
		if (![currentThread isCancelled]) {
			NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
			NSLog(@"Loaded %i commits in %f seconds (%f/sec)", num, duration, num/duration);
			
			// Make sure the commits are stored before exiting.
			NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:currentThread, kRevListThreadKey, revisions, kRevListRevisionsKey, nil];
			[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:YES];
			
			[self performSelectorOnMainThread:@selector(finishedParsing) withObject:nil waitUntilDone:NO];
		}
		else {
			NSLog(@"[%@ %@] thread has been canceled", [self class], NSStringFromSelector(_cmd));
		}
		
		[task terminate];
		[task waitUntilExit];
	}
}

@end
