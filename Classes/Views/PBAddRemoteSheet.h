//
//  PBAddRemoteSheet.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/8/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RJModalRepoSheet.h"
@class PBGitRepository;

@interface PBAddRemoteSheet : RJModalRepoSheet

- (id) initWithRepository:(PBGitRepository*)repo;

- (IBAction) browseFolders:(id)sender;
- (IBAction) addRemote:(id)sender;
- (IBAction) showHideHiddenFiles:(id)sender;
- (IBAction) cancelOperation:(id)sender;

@property (readwrite, weak) IBOutlet NSTextField *remoteName;
@property (readwrite, weak) IBOutlet NSTextField *remoteURL;
@property (readwrite, weak) IBOutlet NSTextField *errorMessage;

@property (readwrite, strong) NSOpenPanel *browseSheet;
@property (readwrite, strong) IBOutlet NSView *browseAccessoryView;

@end
