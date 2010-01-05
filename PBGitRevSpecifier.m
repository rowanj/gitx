//
//  PBGitRevSpecifier.m
//  GitX
//
//  Created by Pieter de Bie on 12-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevSpecifier.h"


@implementation PBGitRevSpecifier

@synthesize parameters, description, workingDirectory;

- (id) initWithParameters:(NSArray*) params
{
	parameters = params;
	description = nil;
	return self;
}

- (id) initWithRef: (PBGitRef*) ref
{
	parameters = [NSArray arrayWithObject: ref.ref];
	description = ref.shortName;
	return self;
}

- (id) initWithCoder:(NSCoder *)coder
{
	parameters = [coder decodeObjectForKey:@"Parameters"];
	description = [coder decodeObjectForKey:@"Description"];
	return self;
}

+ (PBGitRevSpecifier *)allBranchesRevSpec
{
	id revspec = [[PBGitRevSpecifier alloc] initWithParameters:[NSArray arrayWithObject:@"--all"]];
	[revspec setDescription:@"All branches"];
	return revspec;
}

+ (PBGitRevSpecifier *)localBranchesRevSpec
{
	id revspec = [[PBGitRevSpecifier alloc] initWithParameters:[NSArray arrayWithObject:@"--branches"]];
	[revspec setDescription:@"Local branches"];
	return revspec;
}
- (BOOL) isSimpleRef
{
	return ([parameters count] == 1 && ![[parameters objectAtIndex:0] hasPrefix:@"-"]);
}

- (NSString*) simpleRef
{
	if (![self isSimpleRef])
		return nil;
	return [parameters objectAtIndex:0];
}

- (NSString*) description
{
	if (description)
		return description;
	
	return [parameters componentsJoinedByString:@" "];
}

- (BOOL) hasPathLimiter;
{
	for (NSString* param in parameters)
		if ([param isEqualToString:@"--"])
			return YES;
	return NO;
}

- (BOOL) hasLeftRight
{
	for (NSString* param in parameters)
		if ([param isEqualToString:@"--left-right"])
			return YES;
	return NO;
}
	
- (BOOL) isEqualTo: (PBGitRevSpecifier*) other
{
	if ([self isSimpleRef] ^ [other isSimpleRef])
		return NO;
	
	if ([self isSimpleRef])
		return [[[self parameters] objectAtIndex: 0] isEqualToString: [other.parameters objectAtIndex: 0]];

	return ([[parameters componentsJoinedByString:@" "] isEqualToString: [other.parameters componentsJoinedByString:@" "]] &&
			 (!description  || [description isEqualToString:other.description]));
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:description forKey:@"Description"];
	[coder encodeObject:parameters forKey:@"Parameters"];
}
@end
