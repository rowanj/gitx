//
//  PBHistorySearchMode.h
//  GitX
//
//  Created by Sven-S. Porst on 2016-12-14
//

#import <Foundation/NSObjCRuntime.h>

#ifndef PBHistorySearchMode_h
#define PBHistorySearchMode_h


typedef NS_ENUM(NSInteger, PBHistorySearchMode) {
	PBHistorySearchModeBasic = 1,
	PBHistorySearchModePickaxe,
	PBHistorySearchModeRegex,
	PBHistorySearchModePath,
	PBHistorySearchModeMax    // always keep this item last
} ;


PBHistorySearchMode PBSearchModeForInteger(NSInteger modeInteger);


#endif /* PBHistorySearchMode_h */
