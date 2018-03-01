//
//  ObjectiveGit+PBCategories.h
//  GitX
//
//  Created by Etienne on 28/02/2017.
//
//

#import "ObjectiveGit+PBCategories.h"


@implementation GTCommit (PBCategories)

// This is an optimisation for the grapher.
// We're only interested in OIDs, and we don't need objects
- (NSArray <GTOID *> *)parentOIDs {
	unsigned numberOfParents = git_commit_parentcount(self.git_commit);
	NSMutableArray <GTOID *> *parents = [NSMutableArray arrayWithCapacity:numberOfParents];

	for (unsigned i = 0; i < numberOfParents; i++) {
		const git_oid *parent = git_commit_parent_id(self.git_commit, i);

		[parents addObject:[GTOID oidWithGitOid:parent]];
	}

	return parents;

}

@end

@interface GTEnumerator (Private)
@property (nonatomic, assign, readonly) git_revwalk *walk;
@end

@implementation GTEnumerator (PBCategories)
- (BOOL)pushReferenceName:(NSString *)refName error:(NSError **)error {
	int gitError = git_revwalk_push_ref(self.walk, refName.UTF8String);
	if (gitError != 0) {
		if (error) *error = [NSError git_errorFor:gitError description:@"Failed to push reference %@", refName];
		return NO;
	}
	return YES;
}
@end
