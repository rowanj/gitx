/*
 * GitX.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class GitXApplication, GitXDocument, GitXWindow;

enum GitXSaveOptions {
	GitXSaveOptionsYes = 'yes ' /* Save the file. */,
	GitXSaveOptionsNo = 'no  ' /* Do not save the file. */,
	GitXSaveOptionsAsk = 'ask ' /* Ask the user whether or not to save the file. */
};
typedef enum GitXSaveOptions GitXSaveOptions;

enum GitXPrintingErrorHandling {
	GitXPrintingErrorHandlingStandard = 'lwst' /* Standard PostScript error handling */,
	GitXPrintingErrorHandlingDetailed = 'lwdt' /* print a detailed report of PostScript errors */
};
typedef enum GitXPrintingErrorHandling GitXPrintingErrorHandling;

@protocol GitXGenericMethods

- (void) closeSaving:(GitXSaveOptions)saving savingIn:(NSURL *)savingIn;  // Close a document.
- (void) printWithProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.
- (void) searchString:(NSString *)string inMode:(NSInteger)inMode;  // Highlight commits that match the given search string.

@end



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface GitXApplication : SBApplication

- (SBElementArray<GitXDocument *> *) documents;
- (SBElementArray<GitXWindow *> *) windows;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (id) open:(id)x;  // Open a document.
- (void) print:(id)x withProperties:(NSDictionary *)withProperties printDialog:(BOOL)printDialog;  // Print a document.
- (void) quitSaving:(GitXSaveOptions)saving;  // Quit the application.
- (BOOL) exists:(id)x;  // Verify that an object exists.
- (id) open:(id)x withOptions:(NSArray<NSString *> *)withOptions;  // Open a document.
- (void) showDiff:(NSString *)x;  // Show the supplied diff output in a GitX window.
- (void) performDiffIn:(NSURL *)x withOptions:(NSArray<NSString *> *)withOptions;  // Perform a diff operation in a repository.
- (void) createRepository:(NSURL *)x;  // Create a git repository at the given filesystem URL.
- (void) cloneRepository:(NSString *)x to:(NSURL *)to isBare:(BOOL)isBare;  // Clone a repository.

@end

// A document.
@interface GitXDocument : SBObject <GitXGenericMethods>

@property (copy, readonly) NSString *name;  // Its name.
@property (readonly) BOOL modified;  // Has it been modified since the last save?
@property (copy, readonly) NSURL *file;  // Its location on disk, if it has one.


@end

// A window.
@interface GitXWindow : SBObject <GitXGenericMethods>

@property (copy, readonly) NSString *name;  // The title of the window.
- (NSInteger) id;  // The unique identifier of the window.
@property NSInteger index;  // The index of the window, ordered front to back.
@property NSRect bounds;  // The bounding rectangle of the window.
@property (readonly) BOOL closeable;  // Does the window have a close button?
@property (readonly) BOOL miniaturizable;  // Does the window have a minimize button?
@property BOOL miniaturized;  // Is the window minimized right now?
@property (readonly) BOOL resizable;  // Can the window be resized?
@property BOOL visible;  // Is the window visible right now?
@property (readonly) BOOL zoomable;  // Does the window have a zoom button?
@property BOOL zoomed;  // Is the window zoomed right now?
@property (copy, readonly) GitXDocument *document;  // The document whose contents are displayed in the window.


@end



/*
 * GitX Suite
 */

// The GitX application.
@interface GitXApplication (GitXSuite)

@end

// A document.
@interface GitXDocument (GitXSuite)

@end

