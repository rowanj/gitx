//
//  PBHistorySearchMode.m
//  GitX
//
//  Created by Sven-S. Porst on 2016-12-14.
//

#import "PBHistorySearchMode.h"

PBHistorySearchMode PBSearchModeForInteger(NSInteger modeInteger) {
	if (modeInteger >= PBHistorySearchModeBasic && modeInteger < PBHistorySearchModeMax) {
		return (PBHistorySearchMode)modeInteger;
	}
	return PBHistorySearchModeBasic;
}
