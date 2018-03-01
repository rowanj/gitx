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
@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) PBGitCommit *commit;
@property (nonatomic, readonly) NSString *message;
@property (nonatomic, readonly) PBGitRef *ref;

@property (nonatomic, readonly) PBGitCommit *indexCommit;
@property (nonatomic, readonly) PBGitCommit *ancestorCommit;

- (id)initWithRepository:(PBGitRepository *)repo stashOID:(GTOID *)stashOID index:(NSInteger)index message:(NSString *)message;

@end
