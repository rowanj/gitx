//
//  PBGitConfig.m
//  GitX
//
//  Created by Pieter de Bie on 14-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitConfig.h"


@implementation PBGitConfig

- init
{
	repositoryPath = nil;
	return self;
}

- initWithRepository:(NSString *)path
{
	repositoryPath = path;
	return self;
}

- (void) writeValue:(NSString *)value forKey:(NSString *)key global:(BOOL)global
{
	[self willChangeValueForKey:[key substringToIndex:[key rangeOfString:@"."].location]];

	NSMutableArray *array = [NSMutableArray arrayWithObject:@"config"];
	if (global)
		[array addObject:@"--global"];
	else {
		[array addObject:@"-f"];
		[array addObject:[repositoryPath stringByAppendingPathComponent:@"config"]];
	}

	[array addObject:key];
	[array addObject:value];

	int ret;
	[PBEasyPipe outputForCommand:[PBGitBinary path]	withArgs:array inDir:nil retValue:&ret];
	if (ret)
		NSLog(@"Writing to config file failed!");
	[self didChangeValueForKey:[key substringToIndex:[key rangeOfString:@"."].location]];
}

- valueForKeyPath:(NSString *)path
{
	NSMutableArray *arguments = [NSMutableArray array];
	if (repositoryPath)
		[arguments addObject:[NSString stringWithFormat:@"--git-dir=%@", repositoryPath]];

	[arguments addObject:@"config"];
	[arguments addObject:@"--get"];
	[arguments addObject:path];

	int ret;
	NSString *value = [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:nil retValue:&ret];

	if (ret)
		return nil;

	return value;
}

- (void) setValue:(id)value forKeyPath:(NSString *)path
{
	// Check if the config option is local. In that case,
	// write it local
	if (repositoryPath) {
		NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"config", @"-f", [repositoryPath stringByAppendingPathComponent:@"config"], @"--get", path, nil];
		int ret;
		[PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:nil retValue:&ret];

		if (!ret) // it's local
			return [self writeValue:value forKey:path global:NO];
	}

	// Check if it exists globally. In that case, write it as a global

	NSArray *arguments = [NSArray arrayWithObjects:@"config", @"--global", @"--get", path, nil];
	int ret;
	[PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:nil retValue:&ret];
	if (!ret) // It exists globally
		return [self writeValue:value forKey:path global:YES];

	// It doesn't exist at all. Write it locally.
	[self writeValue:value forKey:path global:NO];
}
@end
