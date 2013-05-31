#ifndef _DCT_WEAK_H
#define _DCT_WEAK_H

// Portable support of notionally weak properties and with ARC
// Forked  from https://gist.github.com/1354106
// Updated by Rowan James
// Available at https://gist.github.com/1530868
// Defines:
//	dct_weak		to be used as a replacement for the 'weak' keyword:
//						@property (dct_weak) NSObject* propertyName;
//	__dct_weak		to be used as a replacement for the '__weak' variable attribute:
//						__dct_weak NSObject* variableName;
//	dct_nil(x)		assigns nil to x only if ARC is not supported

#import <Availability.h>

#define dct_arc_MIN_IOS_SDK				40300
#define dct_arc_MIN_IOS_TARGET			40300
#define dct_arc_MIN_IOS_WEAK_TARGET		50000

#define dct_arc_MIN_OS_X_SDK			1070
#define dct_arc_MIN_OS_X_TARGET			1060
#define dct_arc_MIN_OS_X_WEAK_TARGET	1070

// iOS conditions
#if defined __IPHONE_OS_VERSION_MAX_ALLOWED
#	if __IPHONE_OS_VERSION_MAX_ALLOWED < dct_arc_MIN_IOS_SDK
#		warning "This program uses ARC which is only available in iOS SDK 4.3 and later."
#	endif
#	if __IPHONE_OS_VERSION_MIN_REQUIRED >= dct_arc_MIN_IOS_WEAK_TARGET
#		define dct_weak weak
#		define __dct_weak __weak
#		define dct_nil(x)
#	elif __IPHONE_OS_VERSION_MIN_REQUIRED >= dct_arc_MIN_IOS_TARGET
#		define dct_weak unsafe_unretained
#		define __dct_weak __unsafe_unretained
#		define dct_nil(x)	x = nil
#	endif

// OS X equivalent
#elif defined __MAC_OS_X_VERSION_MIN_REQUIRED
	// check for the OS X 10.7 SDK (can still target 10.6 with ARC using it)
#	if __MAC_OS_X_VERSION_MAX_ALLOWED < dct_arc_MIN_OS_X_SDK 
#		warning "This program uses ARC which is only available in OS X SDK 10.7 and later."
#	endif
#	if __MAC_OS_X_VERSION_MIN_REQUIRED >= dct_arc_MIN_OS_X_WEAK_TARGET
#		define dct_weak weak
#		define __dct_weak __weak
#		define dct_nil(x)
#	elif __MAC_OS_X_VERSION_MIN_REQUIRED >= dct_arc_MIN_OS_X_TARGET
#		define dct_weak unsafe_unretained
#		define __dct_weak __unsafe_unretained
#		define dct_nil(x)	x = nil
#	endif
#else

// Couldn't determine the platform, but ARC is still needed, so...
#	warning "This program requires ARC but we couldn't determine if your environment supports it"
#endif

#endif // include guard
