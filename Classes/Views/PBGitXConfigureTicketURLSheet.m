//
//  PBGitXConfigureTicketURLSheet.m
//  GitX
//
//  Created by Mathias Leppich on 7/11/13.
//  Copyright 2013 Mathias Leppich. All rights reserved.
//

#import "PBGitXConfigureTicketURLSheet.h"

#import "PBGitRepository.h"
#import <ObjectiveGit/GTRepository.h>
#import <ObjectiveGit/GTConfiguration.h>

@interface PBGitXConfigureTicketURLSheet ()

@end

@implementation PBGitXConfigureTicketURLSheet

@synthesize iconView, ticketURLTextField;


#pragma mark -
#pragma mark PBGitXConfigureTicketURLSheet 

+ (void)beginConfigureTicketURLSheetForRepo:(PBGitRepository *)repo
{
    PBGitXConfigureTicketURLSheet *sheet = [[self alloc] initWithWindowNibName:@"PBGitXConfigureTicketURLSheet"
                                                                       forRepo:repo];
    [sheet beginConfigureTicketURLSheet];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
					forRepo:(PBGitRepository *)repo
{
	self = [super initWithWindowNibName:windowNibName forRepo:repo];
	if (!self)
		return nil;
	return self;
}

- (IBAction)closeMessageSheet:(id)sender
{
	[self hide];
}

#pragma mark Private
- (void)beginConfigureTicketURLSheet {
    [self window];
    
    [self loadSettings];
    
    [self show];
}

- (void)loadSettings {
    NSError *error = nil;
    GTConfiguration* config = [self.repository.gtRepo configurationWithError:&error];
	NSString * currentTicketURL = [config stringForKey:GITX_TICKET_URL_SETTING];
    if (currentTicketURL == nil) {
        currentTicketURL = @"";
    }
    ticketURLTextField.stringValue = currentTicketURL;
    NSLog(@"loadSettings: %@", currentTicketURL);
}

- (void)persistSettings {
   	NSString * currentTicketURL = [ticketURLTextField stringValue];
    NSLog(@"persistSettings: %@", currentTicketURL);
    NSError *error = nil;
    GTConfiguration* config = [self.repository.gtRepo configurationWithError:&error];
    if ([currentTicketURL isEqualToString:@""]) {
        [config deleteValueForKey:GITX_TICKET_URL_SETTING error:&error];
    } else {
        [config setString:currentTicketURL forKey:GITX_TICKET_URL_SETTING];
    }
}

- (void)show {
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(controlTextDidChange:)
                                                 name: NSControlTextDidChangeNotification
                                               object: ticketURLTextField];
    [super show];
}

- (void)hide {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [super hide];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(persistSettings) withObject:self afterDelay:0.2];
}

@end
