//
//  PBGitRevSpecifier.m
//  GitX
//
//  Created by Pieter de Bie on 12-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevSpecifier.h"
#import "PBGitRef.h"

@implementation PBGitRevSpecifier

@synthesize parameters, description, workingDirectory;
@synthesize isSimpleRef;

// I believe this relates loosely to parts of git-check-ref-format.
// cf. https://www.kernel.org/pub/software/scm/git/docs/git-check-ref-format.html
//
NS_INLINE BOOL ContainsComplexRefCharSequence(NSString *refString)
{
	return ([refString hasPrefix:@"-"] ||
			[refString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" ~^:"]].location != NSNotFound ||
			[refString rangeOfString:@".."].location != NSNotFound ||
			[refString rangeOfString:@"@{"].location != NSNotFound);
}

// internal designated init
- (id) initWithParameters:(NSArray *)params description:(NSString *)descrip
{
	NSParameterAssert(params != nil);

	self = [super init];
	if (!self) return nil;

	parameters = params;
	description = descrip;
	isSimpleRef = (params.count == 1) && !ContainsComplexRefCharSequence(params[0]);

	return self;
}

- (id) initWithParameters:(NSArray *)params
{
	return [self initWithParameters:params description:nil];
}

- (id) initWithRef:(PBGitRef *)ref
{
	return [self initWithParameters:[NSArray arrayWithObject:ref.ref] description:ref.shortName];
}

- (id) initWithCoder:(NSCoder *)coder
{
	return [self initWithParameters:[coder decodeObjectForKey:@"Parameters"] description:[coder decodeObjectForKey:@"Description"]];
}

+ (PBGitRevSpecifier *)allBranchesRevSpec
{
    // Using --all here would include refs like refs/notes/commits, which probably isn't what we want.
	return [[PBGitRevSpecifier alloc] initWithParameters:@[@"--branches", @"--remotes", @"--tags", @"--glob=refs/stash*", @"HEAD"] description:@"All branches"];
}

+ (PBGitRevSpecifier *)localBranchesRevSpec
{
	return [[PBGitRevSpecifier alloc] initWithParameters:@[@"--branches", @"HEAD"] description:@"Local branches"];
}

- (NSString*) simpleRef
{
	if (![self isSimpleRef])
		return nil;
	return [parameters objectAtIndex:0];
}

- (PBGitRef *) ref
{
	if (![self isSimpleRef])
		return nil;

	return [PBGitRef refFromString:[self simpleRef]];
}

- (NSString *) description
{
	if (!description)
		return [parameters componentsJoinedByString:@" "];

	return description;
}

- (void) setDescription:(NSString *)newDescription
{
	description = newDescription;
}


- (NSString *) title
{
	NSString *title = nil;
	
	if ([self.description isEqualToString:@"HEAD"])
		title = @"detached HEAD";
	else if ([self isSimpleRef])
		title = [[self ref] shortName];
	else if ([self.description hasPrefix:@"-S"])
		title = [self.description substringFromIndex:[@"-S" length]];
	else if ([self.description hasPrefix:@"HEAD -- "])
		title = [self.description substringFromIndex:[@"HEAD -- " length]];
	else if ([self.description hasPrefix:@"-- "])
		title = [self.description substringFromIndex:[@"-- " length]];
	else
		title = self.description;
	
	return [NSString stringWithFormat:@"“%@”", title];
}

- (BOOL) hasPathLimiter;
{
	for (NSString* param in parameters)
		if ([param isEqualToString:@"--"])
			return YES;
	return NO;
}

- (BOOL) isEqual:(PBGitRevSpecifier *)other
{
	if ([self isSimpleRef] ^ [other isSimpleRef])
		return NO;
	
	if ([self isSimpleRef])
		return [[[self parameters] objectAtIndex:0] isEqualToString:[other.parameters objectAtIndex:0]];

	return [self.description isEqualToString:other.description];
}

- (NSUInteger) hash
{
	if ([self isSimpleRef])
		return [[[self parameters] objectAtIndex:0] hash];

	return [self.description hash];
}

- (BOOL) isAllBranchesRev
{
	return [self isEqual:[PBGitRevSpecifier allBranchesRevSpec]];
}

- (BOOL) isLocalBranchesRev
{
	return [self isEqual:[PBGitRevSpecifier localBranchesRevSpec]];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:description forKey:@"Description"];
	[coder encodeObject:parameters forKey:@"Parameters"];
}

- (id)copyWithZone:(NSZone *)zone
{
    PBGitRevSpecifier *copy = [[[self class] allocWithZone:zone] initWithParameters:[self.parameters copy]];
    copy.description = [self.description copy];
	copy.workingDirectory = [self.workingDirectory copy];

    return copy;
}

@end
