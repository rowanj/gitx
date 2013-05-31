/*
 *  Extension for NSFileHandle to make it capable of easy network programming
 *
 *  Version 1.0, get the newest from http://michael.stapelberg.de/NSFileHandleExt.php
 *
 *  Copyright 2007 Michael Stapelberg
 *
 *  Distributed under BSD-License, see http://michael.stapelberg.de/BSD.php
 *
 */

#import <Cocoa/Cocoa.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>

@interface NSFileHandle(NSFileHandleExt)
-(NSString*)readLine;
@end
