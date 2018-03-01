//
//  PBGitXProtocol.h
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class PBGitRepository;

@interface PBGitXProtocol : NSURLProtocol
@end

@interface NSURLRequest (PBGitXProtocol)
@property (nonatomic, strong) PBGitRepository *repository;
@end

@interface NSMutableURLRequest (PBGitXProtocol)
@property (nonatomic, strong) PBGitRepository *repository;
@end

