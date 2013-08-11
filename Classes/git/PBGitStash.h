//
//  PBGitStash.h
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import <Foundation/Foundation.h>
#import <ObjectiveGit/ObjectiveGit.h>

@class PBGitCommit;
@class PBGitRef;
@class PBGitRepository;

@interface PBGitStash : NSObject
@property (nonatomic, readonly) size_t index;
@property (nonatomic, readonly) PBGitCommit * commit;
@property (nonatomic, readonly) NSString* message;
@property (nonatomic, readonly) PBGitRef* ref;

@property (nonatomic, readonly) PBGitCommit * indexCommit;
@property (nonatomic, readonly) PBGitCommit * ancesterCommit;

- (id) initWithRepository:(PBGitRepository *)repo stashOID:(git_oid)stash_id index:(size_t)index message:(NSString *)message;

@end
