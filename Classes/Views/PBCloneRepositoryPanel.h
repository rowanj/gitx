//
//  PBCloneRepositoryPanel.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBCloneRepositoryPanel : NSWindowController {
	NSOpenPanel *browseRepositoryPanel;
	NSOpenPanel *browseDestinationPanel;

	NSString *path;
	BOOL isBare;
}

+ (id) panel;
+ (void)beginCloneRepository:(NSString *)repository toURL:(NSURL *)targetURL isBare:(BOOL)bare;

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText;
- (void)showErrorSheet:(NSError *)error;

- (IBAction) closeCloneRepositoryPanel:(id)sender;
- (IBAction) clone:(id)sender;
- (IBAction) browseRepository:(id)sender;
- (IBAction) showHideHiddenFiles:(id)sender;
- (IBAction) browseDestination:(id)sender;

@property (nonatomic, dct_weak) IBOutlet NSTextField *repositoryURL;
@property (nonatomic, dct_weak) IBOutlet NSTextField *destinationPath;
@property (nonatomic, dct_weak) IBOutlet NSTextField *errorMessage;
@property (nonatomic, dct_weak) IBOutlet NSView      *repositoryAccessoryView;

@property (assign) BOOL isBare;

@end
