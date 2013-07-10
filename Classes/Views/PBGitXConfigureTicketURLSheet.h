//
//  PBGitXConfigureTicketURLSheet.h
//  GitX
//
//  Created by Mathias Leppich on 7/11/13.
//  Copyright 2013 Mathias Leppich. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RJModalRepoSheet.h"

#define GITX_TICKET_URL_SETTING @"gitx.ticketurl"

@interface PBGitXConfigureTicketURLSheet : RJModalRepoSheet
{
	NSImageView *iconView;
    NSTextField *ticketURLTextField;
}

+ (void)beginConfigureTicketURLSheetForRepo:(PBGitRepository *)repo;

- (void)beginConfigureTicketURLSheet;

- (IBAction)closeMessageSheet:(id)sender;

@property  IBOutlet NSImageView *iconView;
@property  IBOutlet NSTextField *ticketURLTextField;

@end
