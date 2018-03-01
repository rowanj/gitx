//
//  PBGitStash.m
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import "PBGitStash.h"
#import "PBGitRef.h"
#import "PBGitCommit.h"
#import "PBGitRepository.h"

@implementation PBGitStash

-(id)initWithRepository:(PBGitRepository *)repo stashOID:(GTOID *)stashOID index:(NSInteger)index message:(NSString *)message
{
	self = [self init];
	if (!self) return nil;

    _index = index;
    _message = message;
    
    GTRepository * gtRepo = repo.gtRepo;
    NSError * error = nil;
    GTCommit * gtCommit = (GTCommit *)[gtRepo lookUpObjectByOID:stashOID objectType:GTObjectTypeCommit error:&error];
    NSArray * parents = [gtCommit parents];
    GTCommit * gtIndexCommit = [parents objectAtIndex:1];
    GTCommit * gtAncestorCommit = [parents objectAtIndex:0];

    _commit = [[PBGitCommit alloc] initWithRepository:repo andCommit:gtCommit];
    _indexCommit = [[PBGitCommit alloc] initWithRepository:repo andCommit:gtIndexCommit];
    _ancestorCommit = [[PBGitCommit alloc] initWithRepository:repo andCommit:gtAncestorCommit];

    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"stash@{%zd}: %@", _index, _message];
}

- (PBGitRef *)ref
{
    NSString * refStr = [NSString stringWithFormat:@"refs/stash@{%zd}", _index];
    return [[PBGitRef alloc] initWithString:refStr];
}

@end
