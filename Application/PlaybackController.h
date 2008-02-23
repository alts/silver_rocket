/* PlaybackController */

#import <Cocoa/Cocoa.h>

#import <Growl/GrowlApplicationBridge.h>

#import "CogAudio/AudioPlayer.h"
#import "TrackingSlider.h"
#import "AudioScrobbler.h"

#define DEFAULT_VOLUME_DOWN 5
#define DEFAULT_VOLUME_UP DEFAULT_VOLUME_DOWN

@class PlaylistController;
@class PlaylistView;

@interface PlaybackController : NSObject <GrowlApplicationBridgeDelegate>
{
    IBOutlet PlaylistController *playlistController;
	IBOutlet PlaylistView *playlistView;
	
	IBOutlet TrackingSlider *positionSlider;
	IBOutlet NSSlider *volumeSlider;
	IBOutlet NSTextField *timeField;
	
	IBOutlet NSSegmentedControl *playbackButtons;
	
	IBOutlet NSArrayController *outputDevices;
	
	NSTimer *positionTimer;
		
	AudioPlayer *audioPlayer;
	
	int playbackStatus;
	
	BOOL showTimeRemaining;
	
	AudioScrobbler *scrobbler;
 }

@property int playbackStatus;

- (IBAction)toggleShowTimeRemaining:(id)sender;
- (IBAction)changeVolume:(id)sender;
- (IBAction)volumeDown:(id)sender;
- (IBAction)volumeUp:(id)sender;

- (IBAction)playPauseResume:(id)sender;
- (IBAction)pauseResume:(id)sender;
- (IBAction)skipToNextAlbum:(id)sender;
- (IBAction)skipToPreviousAlbum:(id)sender;
- (IBAction)playbackButtonClick:(id)sender;

- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)resume:(id)sender;
- (IBAction)stop:(id)sender;

- (IBAction)next:(id)sender;
- (IBAction)prev:(id)sender;
- (IBAction)seek:(id)sender;
- (IBAction)eventSeekForward:(id)sender;
- (void)seekForward:(double)sender;
- (IBAction)eventSeekBackward:(id)sender;
- (void)seekBackward:(double)amount;
- (IBAction)fade:(id)sender;

- (void)initDefaults;
- (void)audioFadeDown:(NSTimer *)audioTimer;
- (void)audioFadeUp:(NSTimer *)audioTimer;

- (void)updateTimeField:(double)pos;

- (void)playEntryAtIndex:(int)i;
- (void)playEntry:(PlaylistEntry *)pe;

@end
