#import "PlaybackController.h"
#import "PlaylistView.h"
#import <Foundation/NSTimer.h>
#import "CogAudio/Status.h"
#import "CogAudio/Helper.h"

#import "PlaylistController.h"
#import "PlaylistEntry.h"

#import "Logging.h"

@implementation PlaybackController

#define DEFAULT_SEEK 5

NSString *CogPlaybackDidBeginNotficiation = @"CogPlaybackDidBeginNotficiation";
NSString *CogPlaybackDidPauseNotficiation = @"CogPlaybackDidPauseNotficiation";
NSString *CogPlaybackDidResumeNotficiation = @"CogPlaybackDidResumeNotficiation";
NSString *CogPlaybackDidStopNotficiation = @"CogPlaybackDidStopNotficiation";

@synthesize playbackStatus;

+ (NSSet *)keyPathsForValuesAffectingSeekable
{
    return [NSSet setWithObjects:@"playlistController.currentEntry",@"playlistController.currentEntry.seekable",nil];
}

- (id)init
{
	self = [super init];
	if (self)
	{
		[self initDefaults];

		seekable = NO;

		audioPlayer = [[AudioPlayer alloc] init];
		[audioPlayer setDelegate:self];
		[self setPlaybackStatus: kCogStatusStopped];
	}

	return self;
}

- (void)initDefaults
{
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithDouble:100.0], @"volume",
		nil];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}



- (void)awakeFromNib
{
	double volume = [[NSUserDefaults standardUserDefaults] doubleForKey:@"volume"];

	[volumeSlider setDoubleValue:logarithmicToLinear(volume)];
	[audioPlayer setVolume:volume];

	[self setSeekable:NO];
}

- (IBAction)playPauseResume:(id)sender
{
	if (playbackStatus == kCogStatusStopped)
	{
		[self play:self];
	}
	else
	{
		[self pauseResume:self];
	}
}

- (IBAction)pauseResume:(id)sender
{
	if (playbackStatus == kCogStatusPaused)
		[self resume:self];
	else
		[self pause:self];
}

- (IBAction)pause:(id)sender
{
	[audioPlayer pause];
	[self setPlaybackStatus: kCogStatusPaused];
}

- (IBAction)resume:(id)sender
{
	[audioPlayer resume];

}

- (IBAction)stop:(id)sender
{
	[audioPlayer stop];
}

//called by double-clicking on table
- (void)playEntryAtIndex:(int)i
{
	PlaylistEntry *pe = [playlistController entryAtIndex:i];

	[self playEntry:pe];
}


- (IBAction)play:(id)sender
{
	if ([playlistView selectedRow] == -1)
		[playlistView selectRow:0 byExtendingSelection:NO];

	if ([playlistView selectedRow] > -1)
		[self playEntryAtIndex:[playlistView selectedRow]];
}

- (void)playEntry:(PlaylistEntry *)pe
{
	if (playbackStatus != kCogStatusStopped)
		[self stop:self];

	DLog(@"PLAYLIST CONTROLLER: %@", [playlistController class]);
	[playlistController setCurrentEntry:pe];

	[self setPosition:0.0];

	if (pe == nil)
		return;

	[audioPlayer play:[pe URL] withUserInfo:pe];
}

- (IBAction)next:(id)sender
{
	if ([playlistController next] == NO)
		return;

	[self playEntry:[playlistController currentEntry]];
}

- (IBAction)prev:(id)sender
{
	if ([playlistController prev] == NO)
		return;

	[self playEntry:[playlistController currentEntry]];
}

- (void)updatePosition:(id)sender
{
	double pos = [audioPlayer amountPlayed];

	[self setPosition:pos];
}

- (IBAction)seek:(id)sender
{
	double time = [sender doubleValue];

    [audioPlayer seekToTime:time];

}

- (IBAction)eventSeekForward:(id)sender
{
	[self seekForward:DEFAULT_SEEK];
}

- (void)seekForward:(double)amount
{
	double seekTo = [audioPlayer amountPlayed] + amount;

	if (seekTo > [[[playlistController currentEntry] length] doubleValue])
	{
		[self next:self];
	}
	else
	{
		[audioPlayer seekToTime:seekTo];
		[self setPosition:seekTo];
	}
}

- (IBAction)eventSeekBackward:(id)sender
{
	[self seekBackward:DEFAULT_SEEK];
}

- (void)seekBackward:(double)amount
{
	double seekTo = [audioPlayer amountPlayed] - amount;

	if (seekTo < 0)
		seekTo = 0;

	[audioPlayer seekToTime:seekTo];
	[self setPosition:seekTo];
}

/*
 - (void)changePlayButtonImage:(NSString *)name
{
	NSImage *img = [NSImage imageNamed:name];
//	[img retain];

	if (img == nil)
	{
		NSLog(@"Error loading image!");
	}

	[playbackButtons setImage:img forSegment:1];
}
*/
- (IBAction)changeVolume:(id)sender
{
	DLog(@"VOLUME: %lf, %lf", [sender doubleValue], linearToLogarithmic([sender doubleValue]));

	[audioPlayer setVolume:linearToLogarithmic([sender doubleValue])];

	[[NSUserDefaults standardUserDefaults] setDouble:[audioPlayer volume] forKey:@"volume"];
}

- (IBAction)volumeDown:(id)sender
{
	double newVolume = [audioPlayer volumeDown:DEFAULT_VOLUME_DOWN];
	[volumeSlider setDoubleValue:logarithmicToLinear(newVolume)];

	[[NSUserDefaults standardUserDefaults] setDouble:[audioPlayer volume] forKey:@"volume"];

}

- (IBAction)volumeUp:(id)sender
{
	double newVolume;
	newVolume = [audioPlayer volumeUp:DEFAULT_VOLUME_UP];
	[volumeSlider setDoubleValue:logarithmicToLinear(newVolume)];

	[[NSUserDefaults standardUserDefaults] setDouble:[audioPlayer volume] forKey:@"volume"];
}

- (void)audioPlayer:(AudioPlayer *)player willEndStream:(id)userInfo
{
	PlaylistEntry *curEntry = (PlaylistEntry *)userInfo;
	PlaylistEntry *pe = [playlistController getNextEntry:curEntry];

	[player setNextStream:[pe URL] withUserInfo:pe];
}

- (void)audioPlayer:(AudioPlayer *)player didBeginStream:(id)userInfo
{
	PlaylistEntry *pe = (PlaylistEntry *)userInfo;

	[playlistController setCurrentEntry:pe];

	[self setPosition:0];

	[[NSNotificationCenter defaultCenter] postNotificationName:CogPlaybackDidBeginNotficiation object:pe];
}

- (void)audioPlayer:(AudioPlayer *)player didChangeStatus:(NSNumber *)s userInfo:(id)userInfo
{
	int status = [s intValue];
	if (status == kCogStatusStopped || status == kCogStatusPaused)
	{
		if (positionTimer)
		{
			[positionTimer invalidate];
			positionTimer = NULL;
		}

		if (status == kCogStatusStopped)
		{
			[self setPosition:0];
			[self setSeekable:NO]; // the player stopped, disable the slider

			[[NSNotificationCenter defaultCenter] postNotificationName:CogPlaybackDidStopNotficiation object:nil];
		}
		else // paused
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:CogPlaybackDidPauseNotficiation object:nil];
		}
	}
	else if (status == kCogStatusPlaying)
	{
		if (!positionTimer) {
			positionTimer = [NSTimer timerWithTimeInterval:1.00 target:self selector:@selector(updatePosition:) userInfo:nil repeats:YES];
			[[NSRunLoop currentRunLoop] addTimer:positionTimer forMode:NSRunLoopCommonModes];
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:CogPlaybackDidResumeNotficiation object:nil];
	}

	if (status == kCogStatusStopped) {
		DLog(@"DONE!");
		[playlistController setCurrentEntry:nil];
		[self setSeekable:NO]; // the player stopped, disable the slider
	}
	else {
		DLog(@"PLAYING!");
		[self setSeekable:YES];
	}

	[self setPlaybackStatus:status];
}

- (void)playlistDidChange:(PlaylistController *)p
{
	[audioPlayer resetNextStreams];
}

- (void)setPosition:(double)p
{
	position = p;
}

- (double)position
{
	return position;
}

- (void)setSeekable:(BOOL)s
{
	seekable = s;
}

- (BOOL)seekable
{
	return seekable && [[playlistController currentEntry] seekable];
}


@end
