//
//  PBMacros.h
//  GitX
//
//  Created by Etienne on 17/02/2017.
//
//

#import <Cocoa/Cocoa.h>

#define GITX_DEPRECATED __attribute__ ((deprecated))
#define GITX_DEPRECATED_MSG(x) __attribute__ ((deprecated(x)))

#define PBLogFunction(x, ...) PBLogFunctionImpl(__FUNCTION__, x, ## __VA_ARGS__)
#define PBLogError(x) PBLogErrorImpl(__FUNCTION__, x)


#ifdef __cplusplus
extern "C" {
#endif

void PBLogFunctionImpl(const char *function, NSString *format, ...);

void PBLogErrorImpl(const char *function, NSError *error);

#ifdef __cplusplus
}
#endif
