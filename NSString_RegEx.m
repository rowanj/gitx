//
//  NSString_RegEx.m
//
//  Created by John R Chang on 2005-11-08.
//  This code is Creative Commons Public Domain.  You may use it for any purpose whatsoever.
//  http://creativecommons.org/licenses/publicdomain/
//

#import "NSString_RegEx.h"
#include <regex.h>


@implementation NSString (RegEx)

- (NSArray *) substringsMatchingRegularExpression:(NSString *)pattern count:(int)nmatch options:(int)options ranges:(NSArray **)ranges error:(NSError **)error
{
	options |= REG_EXTENDED;
	if (error)
		*error = nil;

	int errcode = 0;
	regex_t preg;
	regmatch_t * pmatch = NULL;
	NSMutableArray * outMatches = nil;
	
	// Compile the regular expression
	errcode = regcomp(&preg, [pattern UTF8String], options);
	if (errcode != 0)
		goto catch_error;	// regcomp error
	
	// Match the regular expression against substring self
	pmatch = calloc(sizeof(regmatch_t), nmatch+1);
	errcode = regexec(&preg, [self UTF8String], (nmatch<0 ? 0 : nmatch+1), pmatch, 0);

	/*if (errcode == REG_NOMATCH)
	{
		outMatches = [NSMutableArray array];
		goto catch_exit;	// no match
	}*/	
	if (errcode != 0)
		goto catch_error;	// regexec error

	if (nmatch == -1)
	{
		outMatches = [NSArray arrayWithObject:self];
		goto catch_exit;	// simple match
	}

	// Iterate through pmatch
	outMatches = [NSMutableArray array];
	if (ranges)
		*ranges = [NSMutableArray array];
	int i;
	for (i=0; i<nmatch+1; i++)
	{
		if (pmatch[i].rm_so == -1 || pmatch[i].rm_eo == -1)
			break;

		NSRange range = NSMakeRange(pmatch[i].rm_so, pmatch[i].rm_eo - pmatch[i].rm_so);
		NSString * substring = [[[NSString alloc] initWithBytes:[self UTF8String] + range.location
														 length:range.length
													   encoding:NSUTF8StringEncoding] autorelease];
		[outMatches addObject:substring];

		if (ranges)
		{
			NSValue * value = [NSValue valueWithRange:range];
			[(NSMutableArray *)*ranges addObject:value];
		}
	}

catch_error:
	if (errcode != 0 && error)
	{
		// Construct error object
		NSMutableDictionary * userInfo = [NSMutableDictionary dictionary];
		char errbuf[256];
		int len = regerror(errcode, &preg, errbuf, sizeof(errbuf));
		if (len > 0)
			[userInfo setObject:[NSString stringWithUTF8String:errbuf] forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:@"regerror" code:errcode userInfo:userInfo];
	}

catch_exit:
	if (pmatch)
		free(pmatch);
	regfree(&preg);
	return outMatches;
}

- (BOOL) grep:(NSString *)pattern options:(int)options
{
	NSArray * substrings = [self substringsMatchingRegularExpression:pattern count:-1 options:options ranges:NULL error:NULL];
	return (substrings && [substrings count] > 0);
}

@end
