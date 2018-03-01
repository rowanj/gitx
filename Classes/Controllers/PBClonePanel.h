//
//  PBClonePanel.h
//  GitX
//
//  Created by Etienne on 02/03/2014.
//
//

#import <Cocoa/Cocoa.h>

@interface PBClonePanel : NSPanel

@property (readonly, strong) IBOutlet NSView *accessoryView;
@property (readonly, strong) IBOutlet NSTextField *remoteURLField;
@property (readonly, strong) IBOutlet NSPathControl *localURLPath;
@property (readonly) NSURL *localURL;
@property (readonly) NSURL *cloneURL;

+ (instancetype)clonePanel;

- (BOOL)runModal;

@end
