//
//  PBWebDiffController.m
//  GitX
//
//  Created by Pieter de Bie on 13-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBWebDiffController.h"


@implementation PBWebDiffController

- (void) awakeFromNib
{
	startFile = @"diff";
	[super awakeFromNib];
	[diffController addObserver:self forKeyPath:@"diff" options:0 context:@"ChangedDiff"];
}

- (void)closeView
{
	[diffController removeObserver:self forKeyPath:@"diff"];

	[super closeView];
}


- (void) didLoad
{
	[self showDiff:diffController.diff];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(__bridge NSString *)context isEqualToString: @"ChangedDiff"])
		[self showDiff:diffController.diff];
}

- (void) showDiff: (NSString *) diff
{
	if (diff == nil || !finishedLoading)
		return;

	id script = self.view.windowScriptObject;
	if ([diff length] == 0)
		[script callWebScriptMethod:@"setMessage" withArguments:[NSArray arrayWithObject:@"There are no differences"]];
	else
		[script callWebScriptMethod:@"showDiff" withArguments:[NSArray arrayWithObject:diff]];
}

@end
