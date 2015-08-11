//
//  PlaybackEventController.m
//  Cog
//
//  Created by Vincent Spader on 3/5/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PlaybackEventController.h"

#import "PlaybackController.h"
#import "PlaylistLoader.h"
#import "PlaylistEntry.h"

@implementation PlaybackEventController

- (id)init
{
	self = [super init];
	if (self)
	{
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:1];
	}

	return self;
}

- (void)dealloc
{
	[queue release];

	[super dealloc];
}

- (void)performPlaybackDidBeginActions:(PlaylistEntry *)pe
{
	// Race here, but the worst that could happen is we re-read the data
	if ([pe metadataLoaded] != YES) {
		[pe performSelectorOnMainThread:@selector(setMetadata:) withObject:[playlistLoader readEntryInfo:pe] waitUntilDone:YES];
	}
}


- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidBegin:) name:CogPlaybackDidBeginNotficiation object:nil];
}


- (void)playbackDidBegin:(NSNotification *)notification
{
	NSOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performPlaybackDidBeginActions:) object:[notification object]];
	[queue addOperation:op];
	[op release];
}

@end
