//
//  NSString_RegEx.h
//
//  Created by John R Chang on 2005-11-08.
//  This code is Creative Commons Public Domain.  You may use it for any purpose whatsoever.
//  http://creativecommons.org/licenses/publicdomain/
//

#import <Foundation/Foundation.h>

/*
	For regular expression help, see re_format(7) man page.
*/

@interface NSString (RegEx)

/*
	Common <options> are REG_ICASE and REG_NEWLINE.  For other possible option flags,
	see regex(3) man page.  You don't need to specify REG_EXTENDED.
	
	<nmatch> is the number of subexpressions to match.
	Returns an array of strings.  The first string is the matching substring,
		the remaining are the matching subexpressions, up to nmatch+1 number.

	If nmatch is -1, works like grep.  Returns an array containing self if matching.
		
	Returns nil if regular expression does not match or if an error has occurred.
*/
- (NSArray *) substringsMatchingRegularExpression:(NSString *)pattern count:(int)nmatch
	options:(int)options ranges:(NSArray **)ranges error:(NSError **)error;

- (BOOL) grep:(NSString *)pattern options:(int)options;

@end
