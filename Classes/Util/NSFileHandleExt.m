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


#define CONN_TIMEOUT 5
#define BUFFER_SIZE 256

@implementation NSFileHandle(NSFileHandleExt)

-(NSString*)readLine {
	// If the socket is closed, return an empty string
	if ([self fileDescriptor] <= 0)
		return @"";
	
	int fd = [self fileDescriptor];
	
	// Allocate BUFFER_SIZE bytes to store the line
	int bufferSize = BUFFER_SIZE;
	char *buffer = (char*)malloc(bufferSize + 1);
	if (buffer == NULL)
		[[NSException exceptionWithName:@"No memory left" reason:@"No more memory for allocating buffer" userInfo:nil] raise];
	buffer[0] = '\0';
	
	int bytesReceived = 0;
	long n = 0;
	
	while (1) {
		n = read(fd, buffer + bytesReceived, 1);
		
		if (n == 0)
			break;
		
		if (n < 0) {
			if (errno == EINTR)
				continue;
			
			free(buffer);
			NSString *reason = [NSString stringWithFormat:@"%s:%d: read() error: %s", __PRETTY_FUNCTION__, __LINE__, strerror(errno)];
			[[NSException exceptionWithName:@"Socket error" reason:reason userInfo:nil] raise];
		}
		
		bytesReceived++;
		
		if (bytesReceived >= bufferSize) {
			// Make buffer bigger
			bufferSize += BUFFER_SIZE;
			buffer = (char *)reallocf(buffer, bufferSize + 1);
			if (buffer == NULL)
				[[NSException exceptionWithName:@"No memory left" reason:@"No more memory for allocating buffer" userInfo:nil] raise];
		}       
		
		char receivedByte = buffer[bytesReceived-1];
		if (receivedByte == '\n') {
			bytesReceived--;
			break;
		}
		
		if (receivedByte == '\r')
			bytesReceived--;
	}       
	
	buffer[bytesReceived] = '\0';
	NSString *retVal = [NSString stringWithCString: buffer  encoding: NSUTF8StringEncoding];
	if ([retVal length] == 0)
		retVal = [NSString stringWithCString: buffer encoding: NSISOLatin1StringEncoding];
	
	free(buffer);
	return retVal;
}

@end
