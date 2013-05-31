/*
 * GitX.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class GitXApplication, GitXDocument, GitXWindow;



/*
 * Standard Suite
 */

// The application's top-level scripting object.
@interface GitXApplication : SBApplication

- (SBElementArray *) documents;
- (SBElementArray *) windows;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the active application?
@property (copy, readonly) NSString *version;  // The version number of the application.

- (void) open:(NSArray *)x;  // Open a document.
- (void) quit;  // Quit the application.
- (BOOL) exists:(id)x;  // Verify that an object exists.
- (void) showDiff:(NSString *)x;  // Show the supplied diff output in a GitX window.
- (void) initRepository:(NSURL *)x;  // Create a git repository at the given filesystem URL.
- (void) cloneRepository:(NSString *)x to:(NSURL *)to isBare:(BOOL)isBare;  // Clone a repository.

@end

// A document.
@interface GitXDocument : SBObject

@property (copy, readonly) NSString *name;  // Its name.
@property (copy, readonly) NSURL *file;  // Its location on disk, if it has one.

- (void) close;  // Close a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.
- (void) searchString:(NSString *)string inMode:(NSInteger)inMode;  // Highlight commits that match the given search string.

@end

// A window.
@interface GitXWindow : SBObject

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

- (void) close;  // Close a document.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy an object.
- (void) moveTo:(SBObject *)to;  // Move an object to a new location.
- (void) searchString:(NSString *)string inMode:(NSInteger)inMode;  // Highlight commits that match the given search string.

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

