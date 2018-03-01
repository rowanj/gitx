//
//  PBGitCommit.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitCommit.h"
#import "PBGitTree.h"
#import "PBGitRef.h"
#import "PBGitDefaults.h"
#import "ObjectiveGit+PBCategories.h"

NSString * const kGitXCommitType = @"commit";

@interface PBGitCommit ()

@property (nonatomic, weak) PBGitRepository *repository;
@property (nonatomic, strong) GTCommit *gtCommit;
@property (nonatomic, copy) NSArray<GTOID *> *parents;

@property (nonatomic, strong) NSString *patch;
@property (nonatomic, strong) GTOID *oid;

@end


@implementation PBGitCommit

+ (NSDateFormatter *)longDateFormatter {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t token;
	dispatch_once(&token, ^{
		NSDateFormatter *f = [[NSDateFormatter alloc] init];
		f.dateStyle = NSDateFormatterLongStyle;
		f.timeStyle = NSDateFormatterLongStyle;
		formatter = f;
	});
	return formatter;
}

- (NSDate *) date
{
	return self.gtCommit.commitDate;
	// previous behaviour was equiv. to:  return self.gtCommit.author.time;
}

- (NSString *) dateString
{
	NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
	[formatter setLocalizedDateFormatFromTemplate:@"%Y-%m-%d %H:%M:%S"];
	return [formatter stringFromDate:self.date];
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


- (NSArray <GTOID *>*)parents
{
	if (!self->_parents) {
		self.parents = self.gtCommit.parentOIDs;
	}
	return self->_parents;
}

- (NSString *)subject
{
	return self.gtCommit.messageSummary;
}

- (NSString *)message
{
	return self.gtCommit.message;
}

- (NSString *)author
{
	NSString *result = self.gtCommit.author.name;
	return result;
}

- (NSString *)authorEmail
{
	return self.gtCommit.author.email;
}

- (NSString *)authorDate
{
	return [[[self class] longDateFormatter] stringFromDate:self.gtCommit.author.time];
}

- (NSString *)committer
{
	GTSignature *sig = self.gtCommit.committer;
	return sig.name;
}

- (NSString *)committerEmail
{
	return self.gtCommit.committer.email;
}

- (NSString *)committerDate
{
	return [[[self class] longDateFormatter] stringFromDate:self.gtCommit.committer.time];
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

- (GTOID *)OID
{
	if (!_oid) {
		_oid = self.gtCommit.OID;
	}
	return _oid;
}

- (NSString *)SHA
{
	return self.OID.SHA;
}

- (BOOL) isOnSameBranchAs:(PBGitCommit *)otherCommit
{
	if (!otherCommit)
		return NO;

	if ([self isEqual:otherCommit])
		return YES;

	return [self.repository isOIDOnSameBranch:otherCommit.OID asOID:self.OID];
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
	return self.OID.hash;
}

- (NSString *) patch
{
	if (self->_patch != nil)
		return _patch;

	NSError *error = nil;
	NSString *p = [self.repository outputOfTaskWithArguments:@[@"format-patch",  @"-1", @"--stdout", self.SHA] error:&error];
	if (!p) {
		PBLogError(error);
		return nil;
	}

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
	return self.repository.refs[self.OID];
}

- (void) setRefs:(NSMutableArray *)refs
{
	self.repository.refs[self.OID] = [NSMutableArray arrayWithArray:refs];
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
	return self.SHA;
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
