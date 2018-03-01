//
//  PBGitRepositoryDocument.h
//  GitX
//
//  Created by Etienne on 31/07/2014.
//
//

#import <Cocoa/Cocoa.h>

@class PBGitRepository;
@class PBGitRevSpecifier;
@class PBGitWindowController;

extern NSString *PBGitRepositoryDocumentType;

@interface PBGitRepositoryDocument : NSDocument

@property (nonatomic, strong, readonly) PBGitRepository *repository;


// Scripting Bridge
- (void)findInModeScriptCommand:(NSScriptCommand *)command;

- (IBAction)showCommitView:(id)sender;
- (IBAction)showHistoryView:(id)sender;

- (void)selectRevisionSpecifier:(PBGitRevSpecifier *)specifier;

- (PBGitWindowController *)windowController;

@end
