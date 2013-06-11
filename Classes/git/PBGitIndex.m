//
//  PBGitIndex.m
//  GitX
//
//  Created by Pieter de Bie on 9/12/09.
//  Copyright 2009 Pieter de Bie. All rights reserved.
//

#import "PBGitIndex.h"
#import "PBGitRepository.h"
#import "PBGitBinary.h"
#import "PBEasyPipe.h"
#import "NSString_RegEx.h"
#import "PBChangedFile.h"

NSString *PBGitIndexIndexRefreshStatus = @"PBGitIndexIndexRefreshStatus";
NSString *PBGitIndexIndexRefreshFailed = @"PBGitIndexIndexRefreshFailed";
NSString *PBGitIndexFinishedIndexRefresh = @"PBGitIndexFinishedIndexRefresh";

NSString *PBGitIndexIndexUpdated = @"GBGitIndexIndexUpdated";

NSString *PBGitIndexCommitStatus = @"PBGitIndexCommitStatus";
NSString *PBGitIndexCommitFailed = @"PBGitIndexCommitFailed";
NSString *PBGitIndexCommitHookFailed = @"PBGitIndexCommitHookFailed";
NSString *PBGitIndexFinishedCommit = @"PBGitIndexFinishedCommit";

NSString *PBGitIndexAmendMessageAvailable = @"PBGitIndexAmendMessageAvailable";
NSString *PBGitIndexOperationFailed = @"PBGitIndexOperationFailed";

@interface PBGitIndex (IndexRefreshMethods)

- (NSArray *)linesFromNotification:(NSNotification *)notification;
- (NSMutableDictionary *)dictionaryForLines:(NSArray *)lines;
- (void)addFilesFromDictionary:(NSMutableDictionary *)dictionary staged:(BOOL)staged tracked:(BOOL)tracked;

- (void)indexStepComplete;

- (void)indexRefreshFinished:(NSNotification *)notification;
- (void)readOtherFiles:(NSNotification *)notification;
- (void)readUnstagedFiles:(NSNotification *)notification;
- (void)readStagedFiles:(NSNotification *)notification;

@end

@interface PBGitIndex ()

// Returns the tree to compare the index to, based
// on whether amend is set or not.
- (NSString *) parentTree;
- (void)postCommitUpdate:(NSString *)update;
- (void)postCommitFailure:(NSString *)reason;
- (void)postCommitHookFailure:(NSString *)reason;
- (void)postIndexChange;
- (void)postOperationFailed:(NSString *)description;
@end

@implementation PBGitIndex

- (id)initWithRepository:(PBGitRepository *)theRepository
{
	if (!(self = [super init]))
		return nil;

	NSAssert(theRepository, @"PBGitIndex requires a repository");

	repository = theRepository;
	NSString* workingPath = theRepository.workingDirectory;
	if (workingPath)
	{
		workingDirectory = [NSURL fileURLWithPath:workingPath];
	}
	files = [NSMutableArray array];

	return self;
}

- (NSArray *)indexChanges
{
	return files;
}

- (void)setAmend:(BOOL)newAmend
{
	if (newAmend == amend)
		return;
	
	amend = newAmend;
	amendEnvironment = nil;

	[self refresh];

	if (!newAmend)
		return;

	// If we amend, we want to keep the author information for the previous commit
	// We do this by reading in the previous commit, and storing the information
	// in a dictionary. This dictionary will then later be read by [self commit:]
	NSString *message = [repository outputForCommand:@"cat-file commit HEAD"];
	NSArray *match = [message substringsMatchingRegularExpression:@"\nauthor ([^\n]*) <([^\n>]*)> ([0-9]+[^\n]*)\n" count:3 options:0 ranges:nil error:nil];
	if (match)
		amendEnvironment = [NSDictionary dictionaryWithObjectsAndKeys:[match objectAtIndex:1], @"GIT_AUTHOR_NAME",
							[match objectAtIndex:2], @"GIT_AUTHOR_EMAIL",
							[match objectAtIndex:3], @"GIT_AUTHOR_DATE",
							nil];

	// Find the commit message
	NSRange r = [message rangeOfString:@"\n\n"];
	if (r.location != NSNotFound) {
		NSString *commitMessage = [message substringFromIndex:r.location + 2];
		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexAmendMessageAvailable
															object: self
														  userInfo:[NSDictionary dictionaryWithObject:commitMessage forKey:@"message"]];
	}
	
}

- (BOOL) amend
{
	return amend;
}

- (void)refresh
{
	// If we were already refreshing the index, we don't want
	// double notifications. As we can't stop the tasks anymore,
	// just cancel the notifications
	refreshStatus = 0;
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter]; 
	[nc removeObserver:self]; 

	// Ask Git to refresh the index
	NSFileHandle *updateHandle = [PBEasyPipe handleForCommand:[PBGitBinary path] 
													 withArgs:[NSArray arrayWithObjects:@"update-index", @"-q", @"--unmerged", @"--ignore-missing", @"--refresh", nil]
														inDir:[workingDirectory path]];

	[nc addObserver:self
		   selector:@selector(indexRefreshFinished:)
			   name:NSFileHandleReadToEndOfFileCompletionNotification
			 object:updateHandle];
	[updateHandle readToEndOfFileInBackgroundAndNotify];

}

- (NSString *) parentTree
{
	NSString *parent = amend ? @"HEAD^" : @"HEAD";
	
	if (![repository parseReference:parent])
		// We don't have a head ref. Return the empty tree.
		return @"4b825dc642cb6eb9a060e54bf8d69288fbee4904";

	return parent;
}

// TODO: make Asynchronous
- (void)commitWithMessage:(NSString *)commitMessage andVerify:(BOOL) doVerify
{
	NSMutableString *commitSubject = [@"commit: " mutableCopy];
	NSRange newLine = [commitMessage rangeOfString:@"\n"];
	if (newLine.location == NSNotFound)
		[commitSubject appendString:commitMessage];
	else
		[commitSubject appendString:[commitMessage substringToIndex:newLine.location]];
	
	NSString *commitMessageFile;
	commitMessageFile = [repository.gitURL.path stringByAppendingPathComponent:@"COMMIT_EDITMSG"];
	
	[commitMessage writeToFile:commitMessageFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

	
	[self postCommitUpdate:@"Creating tree"];
	NSString *tree = [repository outputForCommand:@"write-tree"];
	if ([tree length] != 40)
		return [self postCommitFailure:@"Creating tree failed"];
	
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"commit-tree", tree, nil];
	NSString *parent = amend ? @"HEAD^" : @"HEAD";
	if ([repository parseReference:parent]) {
		[arguments addObject:@"-p"];
		[arguments addObject:parent];
	}

	[self postCommitUpdate:@"Creating commit"];
	int ret = 1;
	
    if (doVerify) {
        [self postCommitUpdate:@"Running hooks"];
        NSString *hookFailureMessage = nil;
        NSString *hookOutput = nil;
        if (![repository executeHook:@"pre-commit" output:&hookOutput]) {
            hookFailureMessage = [NSString stringWithFormat:@"Pre-commit hook failed%@%@",
                                  [hookOutput length] > 0 ? @":\n" : @"",
                                  hookOutput];
        }

        if (![repository executeHook:@"commit-msg" withArgs:[NSArray arrayWithObject:commitMessageFile] output:nil]) {
            hookFailureMessage = [NSString stringWithFormat:@"Commit-msg hook failed%@%@",
                                  [hookOutput length] > 0 ? @":\n" : @"",
                                  hookOutput];
        }

        if (hookFailureMessage != nil) {
            return [self postCommitHookFailure:hookFailureMessage];
        }
    }
	
	commitMessage = [NSString stringWithContentsOfFile:commitMessageFile encoding:NSUTF8StringEncoding error:nil];
	
	NSString *commit = [repository outputForArguments:arguments
										  inputString:commitMessage
							   byExtendingEnvironment:amendEnvironment
											 retValue: &ret];
	
	if (ret || [commit length] != 40)
		return [self postCommitFailure:@"Could not create a commit object"];
	
	[self postCommitUpdate:@"Updating HEAD"];
	[repository outputForArguments:[NSArray arrayWithObjects:@"update-ref", @"-m", commitSubject, @"HEAD", commit, nil]
						  retValue: &ret];
	if (ret)
		return [self postCommitFailure:@"Could not update HEAD"];
	
	[self postCommitUpdate:@"Running post-commit hook"];
	
	BOOL success = [repository executeHook:@"post-commit" output:nil];
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:success] forKey:@"success"];
	NSString *description;  
	if (success)
		description = [NSString stringWithFormat:@"Successfully created commit %@", commit];
	else
		description = [NSString stringWithFormat:@"Post-commit hook failed, but successfully created commit %@", commit];
	
	[userInfo setObject:description forKey:@"description"];
	[userInfo setObject:commit forKey:@"sha"];

	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexFinishedCommit
														object:self
													  userInfo:userInfo];
	if (!success)
		return;

	repository.hasChanged = YES;

	amendEnvironment = nil;
	if (amend)
		self.amend = NO;
	else
		[self refresh];
	
}

- (void)postCommitUpdate:(NSString *)update
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexCommitStatus
													object:self
													  userInfo:[NSDictionary dictionaryWithObject:update forKey:@"description"]];
}

- (void)postCommitFailure:(NSString *)reason
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexCommitFailed
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:reason forKey:@"description"]];
}

- (void)postCommitHookFailure:(NSString *)reason
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexCommitHookFailed
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:reason forKey:@"description"]];
}

- (void)postOperationFailed:(NSString *)description
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexOperationFailed
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:description forKey:@"description"]];	
}

- (BOOL)stageFiles:(NSArray *)stageFiles
{
	// Do staging files by chunks of 1000 files each, to prevent program freeze (because NSPipe has limited capacity)
	
	int filesCount = [stageFiles count];
	
	// Prepare first iteration
	int loopFrom = 0;
	int loopTo = 1000;
	if (loopTo > filesCount)
		loopTo = filesCount;
	int loopCount = 0;
	int i = 0;
	
	// Staging
	while (loopCount < filesCount) {
		// Input string for update-index
		// This will be a list of filenames that
		// should be updated. It's similar to
		// "git add -- <files>
		NSMutableString *input = [NSMutableString string];

		for (i = loopFrom; i < loopTo; i++) {
			loopCount++;
			
			PBChangedFile *file = [stageFiles objectAtIndex:i];
			
			[input appendFormat:@"%@\0", file.path];
		}
		
			
		int ret = 1;
		[repository outputForArguments:[NSArray arrayWithObjects:@"update-index", @"--add", @"--remove", @"-z", @"--stdin", nil]
						   inputString:input
							  retValue:&ret];

		if (ret) {
			[self postOperationFailed:[NSString stringWithFormat:@"Error in staging files. Return value: %i", ret]];
			return NO;
		}

		for (i = loopFrom; i < loopTo; i++) {
			PBChangedFile *file = [stageFiles objectAtIndex:i];
			
			file.hasUnstagedChanges = NO;
			file.hasStagedChanges = YES;
		}
		
		// Prepare next iteration
		loopFrom = loopCount;
		loopTo = loopFrom + 1000;
		if (loopTo > filesCount)
			loopTo = filesCount;
	}

	[self postIndexChange];
	return YES;
}

// TODO: Refactor with above. What's a better name for this?
- (BOOL)unstageFiles:(NSArray *)unstageFiles
{
	// Do unstaging files by chunks of 1000 files each, to prevent program freeze (because NSPipe has limited capacity)
	
	int filesCount = [unstageFiles count];
	
	// Prepare first iteration
	int loopFrom = 0;
	int loopTo = 1000;
	if (loopTo > filesCount)
		loopTo = filesCount;
	int loopCount = 0;
	int i = 0;
	
	// Unstaging
	while (loopCount < filesCount) {
		NSMutableString *input = [NSMutableString string];
		
		for (i = loopFrom; i < loopTo; i++) {
			loopCount++;
			
			PBChangedFile *file = [unstageFiles objectAtIndex:i];
			
			[input appendString:[file indexInfo]];
		}
		
		int ret = 1;
		[repository outputForArguments:[NSArray arrayWithObjects:@"update-index", @"-z", @"--index-info", nil]
						   inputString:input
							  retValue:&ret];
		
		if (ret)
		{
			[self postOperationFailed:[NSString stringWithFormat:@"Error in unstaging files. Return value: %i", ret]];
			return NO;
		}
		
		for (i = loopFrom; i < loopTo; i++) {
			PBChangedFile *file = [unstageFiles objectAtIndex:i];
			
			file.hasUnstagedChanges = YES;
			file.hasStagedChanges = NO;
		}
		
		// Prepare next iteration
		loopFrom = loopCount;
		loopTo = loopFrom + 1000;
		if (loopTo > filesCount)
			loopTo = filesCount;
	}

	[self postIndexChange];
	return YES;
}

- (void)discardChangesForFiles:(NSArray *)discardFiles
{
	NSArray *paths = [discardFiles valueForKey:@"path"];
	NSString *input = [paths componentsJoinedByString:@"\0"];

	NSArray *arguments = [NSArray arrayWithObjects:@"checkout-index", @"--index", @"--quiet", @"--force", @"-z", @"--stdin", nil];

	int ret = 1;
	[PBEasyPipe outputForCommand:[PBGitBinary path]	withArgs:arguments inDir:[workingDirectory path] inputString:input retValue:&ret];

	if (ret) {
		[self postOperationFailed:[NSString stringWithFormat:@"Discarding changes failed with return value %i", ret]];
		return;
	}

	for (PBChangedFile *file in discardFiles)
		if (file.status != NEW)
			file.hasUnstagedChanges = NO;

	[self postIndexChange];
}

- (BOOL)applyPatch:(NSString *)hunk stage:(BOOL)stage reverse:(BOOL)reverse;
{
	NSMutableArray *array = [NSMutableArray arrayWithObjects:@"apply", @"--unidiff-zero", nil];
	if (stage)
		[array addObject:@"--cached"];
	if (reverse)
		[array addObject:@"--reverse"];

	int ret = 1;
	NSString *error = [repository outputForArguments:array
										 inputString:hunk
											retValue:&ret];

	if (ret) {
		[self postOperationFailed:[NSString stringWithFormat:@"Applying patch failed with return value %i. Error: %@", ret, error]];
		return NO;
	}

	// TODO: Try to be smarter about what to refresh
	[self refresh];
	return YES;
}


- (NSString *)diffForFile:(PBChangedFile *)file staged:(BOOL)staged contextLines:(NSUInteger)context
{
	NSString *parameter = [NSString stringWithFormat:@"-U%lu", (unsigned long)context];
	if (staged) {
		NSString *indexPath = [@":0:" stringByAppendingString:file.path];

		if (file.status == NEW)
			return [repository outputForArguments:[NSArray arrayWithObjects:@"show", indexPath, nil]];

		return [repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-index", parameter, @"--cached", [self parentTree], @"--", file.path, nil]];
	}

	// unstaged
	if (file.status == NEW) {
		NSStringEncoding encoding;
		NSError *error = nil;
		NSString *path = [[repository workingDirectory] stringByAppendingPathComponent:file.path];
		NSString *contents = [NSString stringWithContentsOfFile:path
												   usedEncoding:&encoding
														  error:&error];
		if (error)
			return nil;

		return contents;
	}

	return [repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-files", parameter, @"--", file.path, nil]];
}

- (void)postIndexChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexIndexUpdated
														object:self];
}

# pragma mark WebKit Accessibility

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

@end

@implementation PBGitIndex (IndexRefreshMethods)

- (void)indexRefreshFinished:(NSNotification *)notification
{
	if ([(NSNumber *)[(NSDictionary *)[notification userInfo] objectForKey:@"NSFileHandleError"] intValue])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexIndexRefreshFailed
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:@"update-index failed" forKey:@"description"]];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexIndexRefreshStatus
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:@"update-index success" forKey:@"description"]];

	// Now that the index is refreshed, we need to read the information from the index
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter]; 

	if ([repository isBareRepository])
	{
		return;
	}
	
	// Other files (not tracked, not ignored)
	refreshStatus++;
	NSFileHandle *handle = [PBEasyPipe handleForCommand:[PBGitBinary path] 
											   withArgs:[NSArray arrayWithObjects:@"ls-files", @"--others", @"--exclude-standard", @"-z", nil]
												  inDir:[workingDirectory path]];
	[nc addObserver:self selector:@selector(readOtherFiles:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];

	// Unstaged files
	refreshStatus++;
	handle = [PBEasyPipe handleForCommand:[PBGitBinary path] 
											   withArgs:[NSArray arrayWithObjects:@"diff-files", @"-z", nil]
												  inDir:[workingDirectory path]];
	[nc addObserver:self selector:@selector(readUnstagedFiles:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];

	// Staged files
	refreshStatus++;
	handle = [PBEasyPipe handleForCommand:[PBGitBinary path] 
								 withArgs:[NSArray arrayWithObjects:@"diff-index", @"--cached", @"-z", [self parentTree], nil]
									inDir:[workingDirectory path]];
	[nc addObserver:self selector:@selector(readStagedFiles:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}

- (void)readOtherFiles:(NSNotification *)notification
{
	NSArray *lines = [self linesFromNotification:notification];
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:[lines count]];
	// Other files are untracked, so we don't have any real index information. Instead, we can just fake it.
	// The line below is not used at all, as for these files the commitBlob isn't set
	NSArray *fileStatus = [NSArray arrayWithObjects:@":000000", @"100644", @"0000000000000000000000000000000000000000", @"0000000000000000000000000000000000000000", @"A", nil];
	for (NSString *path in lines) {
		if ([path length] == 0)
			continue;
		[dictionary setObject:fileStatus forKey:path];
	}

	[self addFilesFromDictionary:dictionary staged:NO tracked:NO];
	[self indexStepComplete];	
}

- (void) readStagedFiles:(NSNotification *)notification
{
	NSArray *lines = [self linesFromNotification:notification];
	NSMutableDictionary *dic = [self dictionaryForLines:lines];
	[self addFilesFromDictionary:dic staged:YES tracked:YES];
	[self indexStepComplete];
}

- (void) readUnstagedFiles:(NSNotification *)notification
{
	NSArray *lines = [self linesFromNotification:notification];
	NSMutableDictionary *dic = [self dictionaryForLines:lines];
	[self addFilesFromDictionary:dic staged:NO tracked:YES];
	[self indexStepComplete];
}

- (void) addFilesFromDictionary:(NSMutableDictionary *)dictionary staged:(BOOL)staged tracked:(BOOL)tracked
{
	// Iterate over all existing files
	for (PBChangedFile *file in files) {
		NSArray *fileStatus = [dictionary objectForKey:file.path];
		// Object found, this is still a cached / uncached thing
		if (fileStatus) {
			if (tracked) {
				NSString *mode = [[fileStatus objectAtIndex:0] substringFromIndex:1];
				NSString *sha = [fileStatus objectAtIndex:2];
				file.commitBlobSHA = sha;
				file.commitBlobMode = mode;
				
				if (staged)
					file.hasStagedChanges = YES;
				else
					file.hasUnstagedChanges = YES;
				if ([[fileStatus objectAtIndex:4] isEqualToString:@"D"])
					file.status = DELETED;
			} else {
				// Untracked file, set status to NEW, only unstaged changes
				file.hasStagedChanges = NO;
				file.hasUnstagedChanges = YES;
				file.status = NEW;
			}

			// We handled this file, remove it from the dictionary
			[dictionary removeObjectForKey:file.path];
		} else {
			// Object not found in the dictionary, so let's reset its appropriate
			// change (stage or untracked) if necessary.

			// Staged dictionary, so file does not have staged changes
			if (staged)
				file.hasStagedChanges = NO;
			// Tracked file does not have unstaged changes, file is not new,
			// so we can set it to No. (If it would be new, it would not
			// be in this dictionary, but in the "other dictionary").
			else if (tracked && file.status != NEW)
				file.hasUnstagedChanges = NO;
			// Unstaged, untracked dictionary ("Other" files), and file
			// is indicated as new (which would be untracked), so let's
			// remove it
			else if (!tracked && file.status == NEW)
				file.hasUnstagedChanges = NO;
		}
	}

	// Do new files only if necessary
	if (![[dictionary allKeys] count])
		return;

	// All entries left in the dictionary haven't been accounted for
	// above, so we need to add them to the "files" array
	[self willChangeValueForKey:@"indexChanges"];
	for (NSString *path in [dictionary allKeys]) {
		NSArray *fileStatus = [dictionary objectForKey:path];

		PBChangedFile *file = [[PBChangedFile alloc] initWithPath:path];
		if ([[fileStatus objectAtIndex:4] isEqualToString:@"D"])
			file.status = DELETED;
		else if([[fileStatus objectAtIndex:0] isEqualToString:@":000000"])
			file.status = NEW;
		else
			file.status = MODIFIED;

		if (tracked) {
			file.commitBlobMode = [[fileStatus objectAtIndex:0] substringFromIndex:1];
			file.commitBlobSHA = [fileStatus objectAtIndex:2];
		}

		file.hasStagedChanges = staged;
		file.hasUnstagedChanges = !staged;

		[files addObject:file];
	}
	[self didChangeValueForKey:@"indexChanges"];
}

# pragma mark Utility methods
- (NSArray *)linesFromNotification:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	if (!data)
		return [NSArray array];

	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	// FIXME: throw an error?
	if (!string)
		return [NSArray array];

	// Strip trailing null
	if ([string hasSuffix:@"\0"])
		string = [string substringToIndex:[string length]-1];

	if ([string length] == 0)
		return [NSArray array];

	return [string componentsSeparatedByString:@"\0"];
}

- (NSMutableDictionary *)dictionaryForLines:(NSArray *)lines
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[lines count]/2];
	
	// Fill the dictionary with the new information. These lines are in the form of:
	// :00000 :0644 OTHER INDEX INFORMATION
	// Filename

	NSAssert1([lines count] % 2 == 0, @"Lines must have an even number of lines: %@", lines);

	NSEnumerator *enumerator = [lines objectEnumerator];
	NSString *fileStatus;
	while (fileStatus = [enumerator nextObject]) {
		NSString *fileName = [enumerator nextObject];
		[dictionary setObject:[fileStatus componentsSeparatedByString:@" "] forKey:fileName];
	}

	return dictionary;
}

// This method is called for each of the three processes from above.
// If all three are finished (self.busy == 0), then we can delete
// all files previously marked as deletable
- (void)indexStepComplete
{
	// if we're still busy, do nothing :)
	if (--refreshStatus) {
		[self postIndexChange];
		return;
	}

	// At this point, all index operations have finished.
	// We need to find all files that don't have either
	// staged or unstaged files, and delete them

	NSMutableArray *deleteFiles = [NSMutableArray array];
	for (PBChangedFile *file in files) {
		if (!file.hasStagedChanges && !file.hasUnstagedChanges)
			[deleteFiles addObject:file];
	}
	
	if ([deleteFiles count]) {
		[self willChangeValueForKey:@"indexChanges"];
		for (PBChangedFile *file in deleteFiles)
			[files removeObject:file];
		[self didChangeValueForKey:@"indexChanges"];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitIndexFinishedIndexRefresh
														object:self];
	[self postIndexChange];

}

@end
