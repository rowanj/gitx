//
//  PBGitCommit.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitTree.h"
#import "PBGitRef.h"
#import "PBGitDefaults.h"

NSString * const kGitXCommitType = @"commit";

@interface PBGitCommit ()

@property (nonatomic, weak) PBGitRepository *repository;
@property (nonatomic, strong) GTCommit *gtCommit;
@property (nonatomic, strong) NSArray *parents;

@property (nonatomic, strong) NSString *patch;
@property (nonatomic, strong) GTOID *sha;

@end


@implementation PBGitCommit

- (NSDate *) date
{
	return self.gtCommit.commitDate;
	// previous behaviour was equiv. to:  return self.gtCommit.author.time;
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

- (id)initWithRepository:(PBGitRepository *)repo andCommit:(GTCommit *)gtCommit
{
	self = [super init];
	if (!self) {
		return nil;
	}
	self.repository = repo;
	self.gtCommit = gtCommit;
	
	return self;
}


- (NSArray *)parents
{
	if (!self->_parents) {
		NSArray *gtParents = self.gtCommit.parents;
		NSMutableArray *parents = [NSMutableArray arrayWithCapacity:gtParents.count];
		for (GTCommit *parent in gtParents) {
			[parents addObject:parent.OID];
		}
		self.parents = parents;
	}
	return self->_parents;
}

- (NSString *)subject
{
	return self.gtCommit.messageSummary;
}

- (NSString *)author
{
	NSString *result = self.gtCommit.author.name;
	return result;
}

- (NSString *)committer
{
	GTSignature *sig = self.gtCommit.committer;
	return sig.name;
}

- (NSString *)SVNRevision
{
	NSString *result = nil;
	if ([self.repository hasSVNRemote])
	{
		// get the git-svn-id from the message
		NSArray *matches = nil;
		NSString *string = self.gtCommit.message;
		NSError *error = nil;
		// Regular expression for pulling out the SVN revision from the git log
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^git-svn-id: .*@(\\d+) .*$" options:NSRegularExpressionAnchorsMatchLines error:&error];
		
		if (string) {
			matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
			for (NSTextCheckingResult *match in matches)
			{
				NSRange matchRange = [match rangeAtIndex:1];
				NSString *matchString = [string substringWithRange:matchRange];
				result = matchString;
			}
		}
	}
	return result;
}

- (GTOID *)sha
{
	GTOID *result = _sha;
	if (result) {
		return result;
	}
    result = self.gtCommit.OID;
	_sha = result;
	return result;
}

- (NSString *)realSha
{
	return self.gtCommit.SHA;
}

- (BOOL) isOnSameBranchAs:(PBGitCommit *)otherCommit
{
	if (!otherCommit)
		return NO;

	if ([self isEqual:otherCommit])
		return YES;

	return [self.repository isOnSameBranch:otherCommit.sha asSHA:self.sha];
}

- (BOOL) isOnHeadBranch
{
	return [self isOnSameBranchAs:[self.repository headCommit]];
}

- (BOOL)isEqual:(id)otherCommit
{
	if (self == otherCommit) {
		return YES;
	}
	return NO;
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
	if (self->_patch != nil)
		return _patch;

	NSString *p = [self.repository outputForArguments:[NSArray arrayWithObjects:@"format-patch",  @"-1", @"--stdout", [self realSha], nil]];
	// Add a GitX identifier to the patch ;)
	self.patch = [[p substringToIndex:[p length] -1] stringByAppendingString:@"+GitX"];
	return self->_patch;
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
	return self.repository.refs[self.sha];
}

- (void) setRefs:(NSMutableArray *)refs
{
	self.repository.refs[self.sha] = [NSMutableArray arrayWithArray:refs];
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
	return self.gtCommit.shortSHA;
}

- (NSString *) refishType
{
	return kGitXCommitType;
}

@end
