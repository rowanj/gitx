//
//  GLFileView.m
//  GitX
//
//  Created by German Laullon on 14/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <MGScopeBar/MGScopeBar.h>

#import "GLFileView.h"
#import "PBGitTree.h"
#import "PBGitCommit.h"
#import "PBGitHistoryController.h"


#define GROUP_LABEL				@"Label"			// string
#define GROUP_SEPARATOR			@"HasSeparator"		// BOOL as NSNumber
#define GROUP_SELECTION_MODE	@"SelectionMode"	// MGScopeBarGroupSelectionMode (int) as NSNumber
#define GROUP_ITEMS				@"Items"			// array of dictionaries, each containing the following keys:
#define ITEM_IDENTIFIER			@"Identifier"		// string
#define ITEM_NAME				@"Name"				// string

#define GROUP_ID_FILEVIEW       @"fileview"
#define GROUP_ID_BLAME          @"blame"
#define GROUP_ID_LOG            @"log"

@interface GLFileView ()

- (void)saveSplitViewPosition;

@end


@implementation GLFileView

- (void) awakeFromNib
{
	NSString *formatFile = [[NSBundle mainBundle] pathForResource:@"format" ofType:@"html" inDirectory:@"html/views/log"];
	if(formatFile!=nil)
		logFormat=[NSString stringWithContentsOfURL:[NSURL fileURLWithPath:formatFile] encoding:NSUTF8StringEncoding error:nil];
	
	
	startFile = GROUP_ID_FILEVIEW;
	//repository = historyController.repository;
	[super awakeFromNib];
	[historyController.treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeController"];
	
	self.groups = [NSMutableArray arrayWithCapacity:0];
	
	NSArray *items = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   startFile, ITEM_IDENTIFIER,
					   @"Source", ITEM_NAME,
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   GROUP_ID_BLAME, ITEM_IDENTIFIER,
					   @"Blame", ITEM_NAME,
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   GROUP_ID_LOG, ITEM_IDENTIFIER,
					   @"History", ITEM_NAME,
					   nil], 
					  nil];
	[self.groups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
							[NSNumber numberWithInt:MGScopeBarGroupSelectionModeRadio], GROUP_SELECTION_MODE, // single selection group.
							items, GROUP_ITEMS, 
							nil]];
	[typeBar reloadData];

	[fileListSplitView setHidden:YES];
	[self performSelector:@selector(restoreSplitViewPositiion) withObject:nil afterDelay:0];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	//NSLog(@"keyPath=%@ change=%@ context=%@ object=%@ \n %@",keyPath,change,context,object,[historyController.treeController selectedObjects]);
	[self showFile];
}

- (void) showFile
{
	NSArray *files=[historyController.treeController selectedObjects];
	if ([files count] > 0) {
		PBGitTree *file = [files objectAtIndex:0];

		NSString *fileTxt = @"";
		if([startFile isEqualToString:GROUP_ID_FILEVIEW])
			fileTxt = [self parseHTML:[file textContents]];
		else if([startFile isEqualToString:GROUP_ID_BLAME])
			fileTxt = [self parseBlame:[file blame]];
		else if([startFile isEqualToString:GROUP_ID_LOG])
			fileTxt = [file log:logFormat];

		id script = [view windowScriptObject];
		NSString *filePath = [file fullPath];
        [script callWebScriptMethod:@"showFile" withArguments:[NSArray arrayWithObjects:fileTxt, filePath, nil]];
	}
	
#if 0
	NSString *dom=[[[[view mainFrame] DOMDocument] documentElement] outerHTML];
	NSString *tmpFile=@"~/tmp/test.html";
	[dom writeToFile:[tmpFile stringByExpandingTildeInPath] atomically:true encoding:NSUTF8StringEncoding error:nil];
#endif 
}

#pragma mark JavaScript log.js methods

- (void) selectCommit:(NSString*)c
{
	[historyController selectCommit: [GTOID oidWithSHA: c]];
}

#pragma mark MGScopeBarDelegate methods

- (NSInteger)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar
{
	return [self.groups count];
}


- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", GROUP_ITEMS, ITEM_IDENTIFIER]];
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_LABEL]; // might be nil, which is fine (nil means no label).
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar titleOfItem:(NSString *)identifier inGroup:(NSInteger)groupNumber
{
	NSArray *items = [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_ITEMS];
	if (items) {
		for (NSDictionary *item in items) {
			if ([[item objectForKey:ITEM_IDENTIFIER] isEqualToString:identifier]) {
				return [item objectForKey:ITEM_NAME];
				break;
			}
		}
	}
	return nil;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber
{
	return [[[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_SELECTION_MODE] intValue];
}

- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(NSInteger)groupNumber
{
	startFile=identifier;
	NSString *path = [NSString stringWithFormat:@"html/views/%@", identifier];
	NSString *html = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
	NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:html]];
	[[view mainFrame] loadRequest:request];
}

- (NSView *)accessoryViewForScopeBar:(MGScopeBar *)scopeBar
{
	return accessoryView;
}

- (void) didLoad
{
	[self showFile];
}

- (void)closeView
{
	[historyController.treeController removeObserver:self forKeyPath:@"selection"];
	[self saveSplitViewPosition];

	[super closeView];
}

- (NSString *) parseHTML:(NSString *)txt
{
	txt=[txt stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	txt=[txt stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	txt=[txt stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	
	return txt;
}

- (NSString *) parseBlame:(NSString *)txt
{
	txt=[self parseHTML:txt];
	
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSString *line;
	NSMutableDictionary *headers=[NSMutableDictionary dictionary];
	NSMutableString *res=[NSMutableString string];
	
	[res appendString:@"<table class='blocks'>\n"];
	int i=0;
	while(i<[lines count]){
		line=[lines objectAtIndex:i];
		NSArray *header=[line componentsSeparatedByString:@" "];
		if([header count]==4){
			NSString *commitID = (NSString *)[header objectAtIndex:0];
			int nLines=[(NSString *)[header objectAtIndex:3] intValue];
			[res appendFormat:@"<tr class='block l%d'>\n",nLines];
			line=[lines objectAtIndex:++i];
			if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"author"]){
				NSString *author=[line stringByReplacingOccurrencesOfString:@"author" withString:@""];
				NSString *summary=nil;
				while(summary==nil){
					line=[lines objectAtIndex:i++];
					if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"summary"]){
						summary=[line stringByReplacingOccurrencesOfString:@"summary" withString:@""];
					}
				}
				NSRange trunc_c={0,7};
				NSString *truncate_c=commitID;
				if([commitID length]>8){
					truncate_c=[commitID substringWithRange:trunc_c];
				}
				NSRange trunc={0,22};
				NSString *truncate_a=author;
				if([author length]>22){
					truncate_a=[author substringWithRange:trunc];
				}
				NSString *truncate_s=summary;
				if([summary length]>30){
					truncate_s=[summary substringWithRange:trunc];
				}
				NSString *block=[NSString stringWithFormat:@"<td><p class='author'><a href='' onclick='selectCommit(\"%@\"); return false;'>%@</a> %@</p><p class='summary'>%@</p></td>\n<td>\n",commitID,truncate_c,truncate_a,truncate_s];
				[headers setObject:block forKey:[header objectAtIndex:0]];
			}
			[res appendString:[headers objectForKey:[header objectAtIndex:0]]];
			
			NSMutableString *code=[NSMutableString string];
			do{
				line=[lines objectAtIndex:i++];
			}while([line characterAtIndex:0]!='\t');
			line=[line substringFromIndex:1];
			line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
			[code appendString:line];
			[code appendString:@"\n"];
			
			int n;
			for(n=1;n<nLines;n++){
				i++;
				do{
					line=[lines objectAtIndex:i++];
				}while([line characterAtIndex:0]!='\t');
				line=[line substringFromIndex:1];
				line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
				[code appendString:line];
				[code appendString:@"\n"];
			}
			[res appendFormat:@"<pre class='first-line: %@;brush: objc'>%@</pre>",[header objectAtIndex:2],code];
			[res appendString:@"</td>\n"];
		}else{
			break;
		}
		[res appendString:@"</tr>\n"];
	}  
	[res appendString:@"</table>\n"];
	//NSLog(@"%@",res);
	
	return (NSString *)res;
}



#pragma mark NSSplitView delegate methods

#define kFileListSplitViewLeftMin 120
#define kFileListSplitViewRightMin 180
#define kHFileListSplitViewPositionDefault @"File List SplitView Position"

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	return kFileListSplitViewLeftMin;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	return [splitView frame].size.width - [splitView dividerThickness] - kFileListSplitViewRightMin;
}

// while the user resizes the window keep the left (file list) view constant and just resize the right view
// unless the right view gets too small
- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [splitView frame];

	float dividerThickness = [splitView dividerThickness];

	NSView *leftView = [[splitView subviews] objectAtIndex:0];
	NSRect leftFrame = [leftView frame];
	leftFrame.size.height = newFrame.size.height;

	if ((newFrame.size.width - leftFrame.size.width - dividerThickness) < kFileListSplitViewRightMin) {
		leftFrame.size.width = newFrame.size.width - kFileListSplitViewRightMin - dividerThickness;
	}

	NSView *rightView = [[splitView subviews] objectAtIndex:1];
	NSRect rightFrame = [rightView frame];
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	rightFrame.size.width = newFrame.size.width - rightFrame.origin.x;
	rightFrame.size.height = newFrame.size.height;

	[leftView setFrame:leftFrame];
	[rightView setFrame:rightFrame];
}

// NSSplitView does not save and restore the position of the SplitView correctly so do it manually
- (void)saveSplitViewPosition
{
	float position = [[[fileListSplitView subviews] objectAtIndex:0] frame].size.width;
	[[NSUserDefaults standardUserDefaults] setFloat:position forKey:kHFileListSplitViewPositionDefault];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// make sure this happens after awakeFromNib
- (void)restoreSplitViewPositiion
{
	float position = [[NSUserDefaults standardUserDefaults] floatForKey:kHFileListSplitViewPositionDefault];
	if (position < 1.0)
		position = 200;

	[fileListSplitView setPosition:position ofDividerAtIndex:0];
	[fileListSplitView setHidden:NO];
}



@synthesize groups;
@synthesize logFormat;

@end
