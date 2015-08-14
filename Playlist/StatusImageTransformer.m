//
//  StatusImageTransformer.m
//  Cog
//
//  Created by Vincent Spader on 2/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "StatusImageTransformer.h"
#import "PlaylistEntry.h"


@implementation StatusImageTransformer

@synthesize playImage;
@synthesize queueImage;
@synthesize errorImage;

+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }

- (id)init
{
	self = [super init];
	if (self)
	{
		self.playImage = [NSImage imageNamed:@"playTemplate"];
		self.queueImage = [NSImage imageNamed:@"NSAddTemplate"];
		self.errorImage = [NSImage imageNamed:@"NSStopProgressTemplate"];
	}

	return self;
}

// Convert from string to RepeatMode
- (id)transformedValue:(id)value {
    if (value == nil) return nil;

	if ([value isEqualToString:@"playing"])
	{
		return self.playImage;
	}
	else if ([value isEqualToString:@"queued"])
	{
		return self.queueImage;
	}
	else if ([value isEqualToString:@"error"]) {
		return self.errorImage;
	}

	return nil;
}


@end
