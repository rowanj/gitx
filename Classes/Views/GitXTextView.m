//
//  GitXTextView.m
//  GitX
//
//  Created by NanoTech on 2016-12-14.
//

#import "GitXTextView.h"

static NSString *AutomaticDashSubstitutionEnabledKey = @"GitXTextViewAutomaticDashSubstitutionEnabled";
static NSString *AutomaticDataDetectionEnabledKey = @"GitXTextViewAutomaticDataDetectionEnabled";
static NSString *AutomaticLinkDetectionEnabledKey = @"GitXTextViewAutomaticLinkDetectionEnabled";
static NSString *AutomaticQuoteSubstitutionEnabled = @"GitXTextViewAutomaticQuoteSubstitutionEnabled";
static NSString *AutomaticSpellingCorrectionEnabledKey = @"GitXTextViewAutomaticSpellingCorrectionEnabled";
static NSString *AutomaticTextReplacementEnabledKey = @"GitXTextViewAutomaticTextReplacementEnabled";
static NSString *SmartInsertDeleteEnabledKey = @"GitXTextViewSmartInsertDeleteEnabled"; // "Smart Copy/Paste"

@implementation GitXTextView

+ (void)initialize
{
	if (self != [GitXTextView class]) return;

	// Matches the commit message text view properties in PBGitCommitView.xib
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		AutomaticDashSubstitutionEnabledKey : @(NO),
		AutomaticDataDetectionEnabledKey : @(NO),
		AutomaticLinkDetectionEnabledKey : @(YES),
		AutomaticQuoteSubstitutionEnabled : @(NO),
		AutomaticSpellingCorrectionEnabledKey : @(NO),
		AutomaticTextReplacementEnabledKey : @(NO),
		SmartInsertDeleteEnabledKey : @(YES),
	}];
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	super.automaticDashSubstitutionEnabled = [defaults boolForKey:AutomaticDashSubstitutionEnabledKey];
	super.automaticDataDetectionEnabled = [defaults boolForKey:AutomaticDataDetectionEnabledKey];
	super.automaticLinkDetectionEnabled = [defaults boolForKey:AutomaticLinkDetectionEnabledKey];
	super.automaticQuoteSubstitutionEnabled = [defaults boolForKey:AutomaticQuoteSubstitutionEnabled];
	super.automaticSpellingCorrectionEnabled = [defaults boolForKey:AutomaticSpellingCorrectionEnabledKey];
	super.automaticTextReplacementEnabled = [defaults boolForKey:AutomaticTextReplacementEnabledKey];
	super.smartInsertDeleteEnabled = [defaults boolForKey:SmartInsertDeleteEnabledKey];
}

- (void)setAutomaticDashSubstitutionEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticDashSubstitutionEnabledKey];
	[super setAutomaticDashSubstitutionEnabled:enabled];
}

- (void)setAutomaticDataDetectionEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticDataDetectionEnabledKey];
	[super setAutomaticDataDetectionEnabled:enabled];
}

- (void)setAutomaticLinkDetectionEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticLinkDetectionEnabledKey];
	[super setAutomaticLinkDetectionEnabled:enabled];
}

- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticQuoteSubstitutionEnabled];
	[super setAutomaticQuoteSubstitutionEnabled:enabled];
}

- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticSpellingCorrectionEnabledKey];
	[super setAutomaticSpellingCorrectionEnabled:enabled];
}

- (void)setAutomaticTextReplacementEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutomaticTextReplacementEnabledKey];
	[super setAutomaticTextReplacementEnabled:enabled];
}

- (void)setSmartInsertDeleteEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:SmartInsertDeleteEnabledKey];
	[super setSmartInsertDeleteEnabled:enabled];
}

@end
