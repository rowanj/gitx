//
//  GitXCommitCopier.m
//  GitX
//
//  Created by Sven-S. Porst on 20.12.15.
//
//

#import "GitXCommitCopier.h"

#import "PBGitCommit.h"

@implementation GitXCommitCopier



#pragma mark Readymade conversions

+ (NSString *) toFullSHA:(NSArray<PBGitCommit *> *)commits {
	NSArray<NSString *> *commitStrings = [self transformCommits:commits with:^(PBGitCommit * commit) {
		return commit.SHA;
	}];
	
	return [commitStrings componentsJoinedByString:@"\n"];
}

+ (NSString *) toShortName:(NSArray<PBGitCommit *> *)commits {
	NSArray<NSString *> *commitStrings = [self transformCommits:commits with:^(PBGitCommit * commit) {
		return commit.shortName;
	}];
	
	return [commitStrings componentsJoinedByString:@" "];
}

+ (NSString *) toSHAAndHeadingString:(NSArray<PBGitCommit *> *)commits {
	NSArray<NSString *> *commitStrings = [self transformCommits:commits with:^(PBGitCommit * commit) {
		return [NSString stringWithFormat:@"%@ (%@)", [commit.SHA substringToIndex:10], commit.subject];
	}];

	return [commitStrings componentsJoinedByString:@"\n"];
}

+ (NSString *) toPatch:(NSArray<PBGitCommit *> *)commits {
	NSArray<NSString *> *commitStrings = [self transformCommits:commits with:^(PBGitCommit * commit) {
		return commit.patch;
	}];
	
	return [commitStrings componentsJoinedByString:@"\n\n\n"];
}



# pragma mark Helpers

+ (NSArray<NSString *> *) transformCommits:(NSArray<PBGitCommit *> *)commits with:(NSString *(^)(PBGitCommit *  commit))transformer {
	
	NSMutableArray *strings = [NSMutableArray arrayWithCapacity:commits.count];
	[commits enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PBGitCommit * _Nonnull commit, NSUInteger idx, BOOL * _Nonnull stop) {
		[strings addObject:transformer(commit)];
	}];
	
	return strings;
}


+ (void) putStringToPasteboard:(NSString *)string {
	if (string.length > 0) {
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard declareTypes:@[NSStringPboardType] owner:self];
		[pasteboard setString:string forType:NSStringPboardType];
	}
}

@end
