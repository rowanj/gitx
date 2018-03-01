//
//  PBGitRepositoryDocument.m
//  GitX
//
//  Created by Etienne on 31/07/2014.
//
//

#import "PBGitRepositoryDocument.h"
#import "PBGitRepository.h"
#import "PBGitWindowController.h"
#import "PBGitRevSpecifier.h"
#import "PBGitBinary.h"
#import "GitXScriptingConstants.h"
#import "PBRepositoryFinder.h"
#import "PBGitDefaults.h"
#import "PBOpenShallowRepositoryErrorRecoveryAttempter.h"
#import "PBError.h"

NSString *PBGitRepositoryDocumentType = @"Git Repository";

@implementation PBGitRepositoryDocument

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if (![PBGitBinary path])
	{
		return PBReturnError(outError, @"Unable to find git", [PBGitBinary notFoundError], nil);
	}

	BOOL isDirectory = FALSE;
	[[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path] isDirectory:&isDirectory];
	if (!isDirectory) {
		return PBReturnError(outError, @"Unable to read files", @"Reading files is not supported", nil);
	}

	_repository = [[PBGitRepository alloc] initWithURL:absoluteURL error:outError];
	if (!_repository) {
		return NO;
	}
	if (_repository.isShallowRepository) {
		if (outError) {
			NSDictionary* userInfo = @{
				NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(
					@"The repository is shallowly cloned, which is not supported by GitX. Please run “git fetch --unshallow” on the repository before opening it with GitX.",
					@"Recovery suggestion when opening a shallow repository"),
				NSLocalizedRecoveryOptionsErrorKey: [PBOpenShallowRepositoryErrorRecoveryAttempter errorDialogButtonNames],
				NSRecoveryAttempterErrorKey: [[PBOpenShallowRepositoryErrorRecoveryAttempter alloc] initWithURL:_repository.workingDirectoryURL]
			};
			*outError = [NSError errorWithDomain:PBGitXErrorDomain code:0 userInfo:userInfo];
		}
		return NO;
	}


	return YES;
}

- (void)close
{
	/* FIXME: Check that this deallocs the repo */
//	[revisionList cleanup];

	[super close];
}

- (BOOL)isDocumentEdited
{
	return NO;
}

- (NSString *)displayName
{
    // Build our display name depending on the current HEAD and whether it's detached or not
    if (self.repository.gtRepo.isHEADDetached)
		return [NSString localizedStringWithFormat:@"%@ (detached HEAD)", self.repository.projectName];

	return [NSString localizedStringWithFormat:@"%@ (branch: %@)", self.repository.projectName, [self.repository.headRef description]];
}

- (void)makeWindowControllers
{
    // Create our custom window controller
#ifndef CLI
	[self addWindowController: [[PBGitWindowController alloc] initWithRepository:self.repository displayDefault:YES]];
#endif
}

- (PBGitWindowController *)windowController
{
	if ([[self windowControllers] count] == 0)
		return NULL;

	return [[self windowControllers] objectAtIndex:0];
}

- (IBAction)showCommitView:(id)sender {
	[[self windowController] showCommitView:sender];
}

- (IBAction)showHistoryView:(id)sender {
	[[self windowController] showHistoryView:sender];
}

- (void)selectRevisionSpecifier:(PBGitRevSpecifier *)specifier {
	PBGitRevSpecifier *spec = [self.repository addBranch:specifier];
	self.repository.currentBranch = spec;
	[self showHistoryView:self];
}

- (void)showWindows
{
	NSScriptCommand *command = [NSScriptCommand currentCommand];

	if (command) {
		NSURL *repoURL = [command directParameter];

		// on app launch there may be many repositories opening, so double check that this is the right repo
		if (repoURL) {
			repoURL = [PBRepositoryFinder gitDirForURL:repoURL];
			if ([repoURL isEqual:self.fileURL]) {
				NSArray *arguments = command.arguments[@"openOptions"];
				[self handleGitXScriptingArguments:arguments];
			}
		}
	}

	[[[self windowController] window] setTitle:[self displayName]];

	[super showWindows];
}

#pragma mark -
#pragma mark AppleScript support

- (void)handleRevListArguments:(NSArray *)arguments
{
	if (![arguments count])
		return;

	PBGitRevSpecifier *revListSpecifier = nil;

	// the argument may be a branch or tag name but will probably not be the full reference
	if ([arguments count] == 1) {
		PBGitRef *refArgument = [self.repository refForName:[arguments lastObject]];
		if (refArgument) {
			revListSpecifier = [[PBGitRevSpecifier alloc] initWithRef:refArgument];
			revListSpecifier.workingDirectory = self.repository.workingDirectoryURL;
		}
	}

	if (!revListSpecifier) {
		revListSpecifier = [[PBGitRevSpecifier alloc] initWithParameters:arguments];
		revListSpecifier.workingDirectory = self.repository.workingDirectoryURL;
	}

	self.repository.currentBranch = [self.repository addBranch:revListSpecifier];
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];
}

- (void)handleBranchFilterEventForFilter:(PBGitXBranchFilterType)filter additionalArguments:(NSArray *)arguments
{
	self.repository.currentBranchFilter = filter;
	[PBGitDefaults setShowStageView:NO];
	[self.windowController showHistoryView:self];

	// treat any additional arguments as a rev-list specifier
	if ([arguments count] > 1) {
		arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count)];
		[self handleRevListArguments:arguments];
	}
}

- (void)handleGitXScriptingArguments:(NSArray *)arguments
{
	if (![arguments count])
		return;

	NSString *firstArgument = [arguments objectAtIndex:0];

	if ([firstArgument isEqualToString:@"-c"] || [firstArgument isEqualToString:@"--commit"]) {
		[PBGitDefaults setShowStageView:YES];
		[self.windowController showCommitView:self];
		return;
	}

	if ([firstArgument isEqualToString:@"--all"]) {
		[self handleBranchFilterEventForFilter:kGitXAllBranchesFilter additionalArguments:arguments];
		return;
	}

	if ([firstArgument isEqualToString:@"--local"]) {
		[self handleBranchFilterEventForFilter:kGitXLocalRemoteBranchesFilter additionalArguments:arguments];
		return;
	}

	if ([firstArgument isEqualToString:@"--branch"]) {
		[self handleBranchFilterEventForFilter:kGitXSelectedBranchFilter additionalArguments:arguments];
		return;
	}

	// if the argument is not a known command then treat it as a rev-list specifier
	[self handleRevListArguments:arguments];
}

// for the scripting bridge
- (void)findInModeScriptCommand:(NSScriptCommand *)command
{
	NSDictionary *arguments = [command arguments];
	NSString *searchString = [arguments objectForKey:kGitXFindSearchStringKey];
	if (searchString) {
		[PBGitDefaults setShowStageView:NO];
		[self.windowController showHistoryView:self];
		PBHistorySearchMode mode = PBSearchModeForInteger([[arguments objectForKey:kGitXFindInModeKey] integerValue]);
		[self.windowController setHistorySearch:searchString mode:mode];
	}
}

@end
