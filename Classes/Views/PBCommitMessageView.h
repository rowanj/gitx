//
//  PBCommitMessageView.h
//  GitX
//
//  Created by Jeff Mesnil on 13/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

#import "GitXTextView.h"

@class PBGitRepository;

@interface PBCommitMessageView : GitXTextView

@property (nonatomic, weak) PBGitRepository *repository;

@end
