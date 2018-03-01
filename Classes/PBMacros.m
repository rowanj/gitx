//
//  PBMacros.m
//  GitX
//
//  Created by Etienne on 17/02/2017.
//
//

#import "PBMacros.h"

#include <stdarg.h>

void PBLogFunctionImpl(const char *function, NSString *format, ...) {
	va_list arg;

	if (!format) {
		NSLog(@"%s", function);
		return;
	}

	va_start(arg, format);

	NSString *log = [[NSString alloc] initWithFormat:format arguments:arg];

	va_end(arg);

	NSLog(@"%s: %@", function, log);
}

void PBLogErrorImpl(const char *function, NSError *error) {
	if (!error) return;
	NSLog(@"%s: %@", function, error);
}
