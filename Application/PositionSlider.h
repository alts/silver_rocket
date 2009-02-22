//
//  PositionSlider.h
//  Cog
//
//  Created by Vincent Spader on 2/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TrackingSlider.h"

@class TimeField;

@interface PositionSlider : TrackingSlider {
	IBOutlet TimeField *positionTextField;
}

@end
