//
//  PBGitTree.m
//  GitTest
//
//  Created by Pieter de Bie on 15-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitTree.h"
#import "PBGitCommit.h"
#import "NSFileHandleExt.h"
#import "PBEasyFS.h"

@implementation PBGitTree

@synthesize sha, path, repository, leaf, parent;

+ (PBGitTree*) rootForCommit:(id) commit
{
	PBGitCommit* c = commit;
	PBGitTree* tree = [[self alloc] init];
	tree.parent = nil;
	tree.leaf = NO;
	tree.sha = c.SHA;
	tree.repository = c.repository;
	tree.path = @"";
	return tree;
}

+ (PBGitTree*) treeForTree: (PBGitTree*) prev andPath: (NSString*) path;
{
	PBGitTree* tree = [[self alloc] init];
	tree.parent = prev;
	tree.sha = prev.sha;
	tree.repository = prev.repository;
	tree.path = path;
	return tree;
}

- init
{
	children = nil;
	localFileName = nil;
	leaf = YES;
	return self;
}

- (NSString*) refSpec
{
	return [NSString stringWithFormat:@"%@:%@", self.sha, self.fullPath];
}

- (BOOL) isLocallyCached
{
	NSFileManager* fs = [NSFileManager defaultManager];
	if (localFileName && [fs fileExistsAtPath:localFileName])
	{
		NSDate* mtime = [[fs attributesOfItemAtPath:localFileName error: nil] objectForKey:NSFileModificationDate];
		if ([mtime compare:localMtime] == 0)
			return YES;
	}
	return NO;
}

- (BOOL)hasBinaryHeader:(NSString*)contents
{
	if (!contents)
		return NO;

	return [contents rangeOfString:@"\0"
						   options:0
							 range:NSMakeRange(0, ([contents length] >= 8000) ? 7999 : [contents length])].location != NSNotFound;
}

- (BOOL)hasBinaryAttributes
{
	@try {
		// First ask git check-attr if the file has a binary attribute custom set
		NSError *error = nil;
		NSString *string = [repository outputOfTaskWithArguments:@[@"check-attr", @"binary", self.fullPath] error:&error];
		
		if (!string)
			return NO;
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		
		if ([string hasSuffix:@"binary: set"])
			return YES;
		
		if ([string hasSuffix:@"binary: unset"])
			return NO;
		
		// Binary state unknown, do a check on common filename-extensions
		for (NSString *extension in [NSArray arrayWithObjects:@".pdf", @".jpg", @".jpeg", @".png", @".bmp", @".gif", @".o", nil]) {
			if ([[self fullPath] hasSuffix:extension])
				return YES;
		}
		
		return NO;
	}
	@catch (NSException *exception) {
		return NO;
	}
}

- (NSString*) contents
{
	if (!leaf)
		return [NSString stringWithFormat:@"This is a tree with path %@", [self fullPath]];

	if ([self isLocallyCached]) {
		NSData *data = [NSData dataWithContentsOfFile:localFileName];
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (!string)
			string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
		return string;
	}

	return [repository outputOfTaskWithArguments:@[@"show", self.refSpec] error:NULL];
}

- (NSString *) blame
{
	if (!leaf)
		return [NSString stringWithFormat:@"This is a tree with path %@", [self fullPath]];
	
	if ([self hasBinaryAttributes])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];
	
	if ([self fileSize] > 52428800) // ~50MB
		return [NSString stringWithFormat:@"%@ is too big to be displayed (%lld bytes)", [self fullPath], [self fileSize]];

	NSString *contents = [repository outputOfTaskWithArguments:@[@"blame", @"-p", sha, @"--", self.fullPath] error:NULL];
	
	if ([self hasBinaryHeader:contents])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];
	
	
	return contents;
}

- (NSString *) log:(NSString *)format
{
	if (!leaf)
		return [NSString stringWithFormat:@"This is a tree with path %@", [self fullPath]];
	
	if ([self hasBinaryAttributes])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];
	
	if ([self fileSize] > 52428800) // ~50MB
		return [NSString stringWithFormat:@"%@ is too big to be displayed (%lld bytes)", [self fullPath], [self fileSize]];

	NSArray *arguments = @[
						   @"log",
						   [NSString stringWithFormat:@"--pretty=format:%@", format],
						   @"--follow",
						   @"--",
						   [self fullPath],
						   ];
	NSString *contents = [repository outputOfTaskWithArguments:arguments error:NULL];

	if ([self hasBinaryHeader:contents])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];
	
	
	return contents;
}

- (long long)fileSize
{
	if (_fileSize)
		return _fileSize;

	NSString *sizeString = [repository outputOfTaskWithArguments:@[@"cat-file", @"-s", self.refSpec] error:NULL];

	if (!sizeString)
		_fileSize = -1;
	else
		_fileSize = [sizeString longLongValue];

	return _fileSize;
}

- (NSString *)textContents
{
	if (!leaf)
		return [NSString stringWithFormat:@"This is a tree with path %@", [self fullPath]];

	if ([self hasBinaryAttributes])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];

	if ([self fileSize] > 52428800) // ~50MB
		return [NSString stringWithFormat:@"%@ is too big to be displayed (%lld bytes)", [self fullPath], [self fileSize]];

	NSString* contents = [self contents];

	if ([self hasBinaryHeader:contents])
		return [NSString stringWithFormat:@"%@ appears to be a binary file of %lld bytes", [self fullPath], [self fileSize]];

	return contents;
}

- (void) saveToFolder: (NSString *) dir
{
	NSString* newName = [dir stringByAppendingPathComponent:path];

	if (leaf) {
		PBTask *task = [repository taskWithArguments:@[@"show", self.refSpec]];

		[task launchTask:NULL];

		[task.standardOutputData writeToFile:newName atomically:YES];
	} else { // Directory
        NSError *error = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:newName withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Error creating directory %@: %@", newName, error);
            return;
        }
		for (PBGitTree* child in [self children])
			[child saveToFolder: newName];
	}
}

- (NSString*) tmpDirWithContents
{
	if (leaf)
		return nil;

	if (!localFileName)
		localFileName = [PBEasyFS tmpDirWithPrefix: path];

	for (PBGitTree* child in [self children]) {
		[child saveToFolder: localFileName];
	}
	
	return localFileName;
}

	

- (NSString*) tmpFileNameForContents
{
	if (!leaf)
		return [self tmpDirWithContents];
	
	if ([self isLocallyCached])
		return localFileName;
	
	if (!localFileName)
		localFileName = [[PBEasyFS tmpDirWithPrefix: sha] stringByAppendingPathComponent:path];


	PBTask *task = [repository taskWithArguments:@[@"show", self.refSpec]];

	[task launchTask:NULL];

	[task.standardOutputData writeToFile:localFileName atomically:YES];
	
	NSFileManager* fs = [NSFileManager defaultManager];
	localMtime = [[fs attributesOfItemAtPath:localFileName error: nil] objectForKey:NSFileModificationDate];

	return localFileName;
}

- (NSArray*) children
{
	if (children != nil)
		return children;
	
	NSString* ref = [self refSpec];

	NSFileHandle* handle = [repository handleForArguments:[NSArray arrayWithObjects:@"show", ref, nil]];
	[handle readLine];
	[handle readLine];
	
	NSMutableArray* c = [NSMutableArray array];
	
	NSString* p = [handle readLine];
	while (p.length > 0) {
		BOOL isLeaf = ([p characterAtIndex:p.length - 1] != '/');
		if (!isLeaf)
			p = [p substringToIndex:p.length -1];

		PBGitTree* child = [PBGitTree treeForTree:self andPath:p];
		child.leaf = isLeaf;
		[c addObject: child];
		
		p = [handle readLine];
	}
	[c sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		PBGitTree* tree1 = (PBGitTree*)obj1;
		PBGitTree* tree2 = (PBGitTree*)obj2;
		return [[tree1 path] localizedStandardCompare:[tree2 path]];
	}];
	children = c;
	return c;
}

- (NSString*) fullPath
{
	if (!parent)
		return @"";
	
	if ([parent.fullPath isEqualToString:@""])
		return self.path;
	
	return [parent.fullPath stringByAppendingPathComponent: self.path];
}

- (void) dealloc
{
	if (localFileName) {
        NSError *error = nil;
		if (![[NSFileManager defaultManager] removeItemAtPath:localFileName error:&error]) {
            NSLog(@"Failed to remove item %@: %@", localFileName, error);
        }
    }
}
@end
