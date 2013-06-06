//
//  PBGitCommit.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitCommit.h"
#import "PBGitSHA.h"
#import "PBGitDefaults.h"


NSString * const kGitXCommitType = @"commit";


@implementation PBGitCommit

@synthesize repository, subject, timestamp, author, sign, lineInfo, SVNRevision;
@synthesize sha;
@synthesize parents;
@synthesize committer;


- (NSDate *)date
{
	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

- (NSString *) dateString
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:NO];
	return [formatter stringFromDate: self.date];
}

- (NSArray*) treeContents
{
	return self.tree.children;
}

+ (PBGitCommit *)commitWithRepository:(PBGitRepository*)repo andSha:(PBGitSHA *)newSha
{
	return [[self alloc] initWithRepository:repo andSha:newSha];
}

- (id)initWithRepository:(PBGitRepository*) repo andSha:(PBGitSHA *)newSha
{
	details = nil;
	repository = repo;
	sha = newSha;
	return self;
}

- (NSString *)realSha
{
	return sha.string;
}

- (BOOL) isOnSameBranchAs:(PBGitCommit *)otherCommit
{
	if (!otherCommit)
		return NO;

	if ([self isEqual:otherCommit])
		return YES;

	return [repository isOnSameBranch:otherCommit.sha asSHA:self.sha];
}

- (BOOL) isOnHeadBranch
{
	return [self isOnSameBranchAs:[repository headCommit]];
}

- (BOOL)isEqual:(id)otherCommit
{
	if (self == otherCommit)
		return YES;

	if (!otherCommit)
		return NO;

	if (![otherCommit isMemberOfClass:[PBGitCommit class]])
		return NO;

	return [self->sha isEqual:((PBGitCommit *)otherCommit)->sha];
}

- (NSUInteger)hash
{
	return [self.sha hash];
}

// FIXME: Remove this method once it's unused.
- (NSString*) details
{
	return @"";
}

- (NSString *) patch
{
	if (_patch != nil)
		return _patch;

	NSString *p = [repository outputForArguments:[NSArray arrayWithObjects:@"format-patch",  @"-1", @"--stdout", [self realSha], nil]];
	// Add a GitX identifier to the patch ;)
	_patch = [[p substringToIndex:[p length] -1] stringByAppendingString:@"+GitX"];
	return _patch;
}

- (PBGitTree*) tree
{
	return [PBGitTree rootForCommit: self];
}

- (void)addRef:(PBGitRef *)ref
{
	if (!self.refs)
		self.refs = [NSMutableArray arrayWithObject:ref];
	else
		[self.refs addObject:ref];
}

- (void)removeRef:(id)ref
{
	if (!self.refs)
		return;

	[self.refs removeObject:ref];
}

- (BOOL) hasRef:(PBGitRef *)ref
{
	if (!self.refs)
		return NO;

	for (PBGitRef *existingRef in self.refs)
		if ([existingRef isEqualToRef:ref])
			return YES;

	return NO;
}

- (NSMutableArray *)refs
{
	return [[repository refs] objectForKey:[self sha]];
}

- (void) setRefs:(NSMutableArray *)refs
{
	[[repository refs] setObject:refs forKey:[self sha]];
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}


#pragma mark <PBGitRefish>

- (NSString *) refishName
{
	return [self realSha];
}

- (NSString *) shortName
{
	return [[self realSha] substringToIndex:10];
}

- (NSString *) refishType
{
	return kGitXCommitType;
}

@end
