//
//  PBRepositoryDocumentController.h
//  GitX
//
//  Created by Ciarán Walsh on 15/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRevSpecifier.h"


@interface PBRepositoryDocumentController : NSDocumentController
{

}

- (id) documentForLocation:(NSURL*) url;
- (void)initNewRepositoryAtURL:(NSURL *)url;
@end
