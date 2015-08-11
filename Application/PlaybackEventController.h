//
//  PlaybackEventController.h
//  Cog
//
//  Created by Vincent Spader on 3/5/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PlaylistLoader;
@interface PlaybackEventController : NSObject {
	NSOperationQueue *queue;

	IBOutlet PlaylistLoader *playlistLoader;
}

@end
