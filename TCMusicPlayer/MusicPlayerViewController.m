//
//  MusicPlayerViewController.m
//  TCMusicPlayer
//
//  Created by Lee Tze Cheun on 7/24/12.
//  Copyright (c) 2012 TC Lee. All rights reserved.
//

#import "MusicPlayerViewController.h"

// Key-Value Observer Contexts.
static void *MusicPlayerViewControllerPlayerItemStatusObserverContext = &MusicPlayerViewControllerPlayerItemStatusObserverContext;

// Properties that we want to load and observe on the AVAsset instance.
NSString * const kStatusKey = @"status";
NSString * const kTracksKey = @"tracks";
NSString * const kPlayableKey = @"playable";
NSString * const kCommonMetadataKey = @"commonMetadata";

#pragma mark - Private Interface

@interface MusicPlayerViewController ()
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) id timeObserver;
@property (assign, nonatomic) float restoreAfterScrubbingRate;

- (void)loadMusic;
- (void)showMetadata:(NSArray*)metadata;
@end

#pragma mark - Player Interface

@interface MusicPlayerViewController (Player)
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (BOOL)isScrubbing;

- (void)assetFailedToPrepareForPlayback:(NSError *)error;
- (void)prepareToPlayAsset:(AVAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

#pragma mark -

@implementation MusicPlayerViewController

#pragma mark - View Controller

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Load the asset and setup player for playback of the asset.
    [self loadMusic];
}

- (void)viewDidUnload
{
    // Clean up. Release all strong references and remove observers.
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification
        object:self.playerItem];
        
    self.player = nil;
    self.playerItem = nil;
    self.timeObserver = nil;
    self.playButton = nil;
    self.pauseButton = nil;
    self.activityIndicatorButton = nil;
        
    [super viewDidUnload];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // To keep things simple, only one orientation is supported.
    return (UIInterfaceOrientationPortrait == interfaceOrientation);
}

#pragma mark - Load Asset

/* Load the music file and set it up for playback as soon as it's ready. */
- (void)loadMusic
{
    // Load the music file from our app bundle. This will be our AVAsset to playback.
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"mp3"];
    AVAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
    
    // Properties of the AVAsset that we want to load asynchronously.
    NSArray *requestedKeys = @[kTracksKey, kPlayableKey, kCommonMetadataKey];
    
    // Tell the asset to load the values of given keys, if they're not loaded yet.
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        // When the values are loaded, we will switch back to the UI thread to update
        // our view accordingly.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self prepareToPlayAsset:asset withKeys:requestedKeys];
        });
    }];
}

#pragma mark - Asset Metadata

/*
 Show the media's metadata on the view.
 (E.g. Song Title, Album Name, Artist Name, Album Artwork)
 */
- (void)showMetadata:(NSArray *)metadata
{
    for (AVMetadataItem* item in metadata) {
        NSString *commonKey = [item commonKey];
        
        if ([commonKey isEqualToString:AVMetadataCommonKeyTitle]) {
            self.songLabel.text = [item stringValue];
        } else if ([commonKey isEqualToString:AVMetadataCommonKeyAlbumName]) {
            self.albumLabel.text = [item stringValue];
        } else if ([commonKey isEqualToString:AVMetadataCommonKeyArtist]) {
            self.artistLabel.text = [item stringValue];
        }
        else if ([commonKey isEqualToString:AVMetadataCommonKeyArtwork]) {
            // Show album artwork.
            NSDictionary *imageDict = (NSDictionary *)[item value];
            UIImage *albumImage = [[UIImage alloc] initWithData: [imageDict objectForKey:@"data"]];
            self.albumImageView.image = albumImage;
        }
    }
}

#pragma mark - UI Actions

/* Play button is tapped to start playing the audio. */
- (IBAction)play:(id)sender 
{    
    [self.player play];
    [self showPauseButton];
}

/* Pause button is tapped to pause the audio. */
- (IBAction)pause:(id)sender 
{
    [self.player pause];     
    [self showPlayButton];
}

#pragma mark - Play, Pause Controls

/* Replace the left-most button on the toolbar with the spinning activity indicator. */
- (void)showActivityIndicator
{
    NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithArray:self.toolbar.items];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.activityIndicatorButton];
    self.toolbar.items = toolbarItems;
}

/* Replace the left-most button on the toolbar with Pause button. */
- (void)showPauseButton
{
    NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithArray:self.toolbar.items];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.pauseButton];
    self.toolbar.items = toolbarItems;
}

/* Replace the left-most button on the toolbar with Play button. */
- (void)showPlayButton
{
    NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithArray:self.toolbar.items];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.playButton];
    self.toolbar.items = toolbarItems;
}

/* Show play or pause button depending on whether the media is currently playing. */
- (void)syncPlayPauseButtons
{
    // If player item is not ready to play yet, the activity indicator will be
    // shown instead.
    if (AVPlayerStatusReadyToPlay != self.playerItem.status) {
        [self showActivityIndicator];
        return;
    }
    
    if ([self isPlaying]) {
        [self showPauseButton];
    } else {
        [self showPlayButton];
    }
}

/* Enable music player controls for user interaction. */
- (void)enablePlayerControls
{
    self.playButton.enabled = YES;
    self.pauseButton.enabled = YES;
    self.scrubber.enabled = YES;
}

/* Disable music player controls to prevent user interaction. */
- (void)disablePlayerControls
{
    self.playButton.enabled = NO;
    self.pauseButton.enabled = NO;
    self.scrubber.enabled = NO;    
}

#pragma mark - Scrubber Control

/* Update the scrubber UI to match the player's current time. */
- (void)syncScrubber
{
    CMTime playerItemDuration = [self playerItemDuration];
    
    // Invalid time, so reset scrubber to 0.
    if (CMTIME_IS_INVALID(playerItemDuration)) {
        self.scrubber.minimumValue = 0.0f;
        return;
    }
    
    // Move scrubber UI to player's current time. 
    double duration = CMTimeGetSeconds(playerItemDuration);
    if (isfinite(duration) && (duration > 0)) {
        float minValue = [self.scrubber minimumValue];
        float maxValue = [self.scrubber maximumValue];
        double time = CMTimeGetSeconds(self.player.currentTime);
        self.scrubber.value = ((maxValue - minValue) * time / duration) + minValue;
    }    
}

/*
 Register time observer on the player to update our scrubber control on a 
 periodic basis. As the music is playing, our scrubber control will be in 
 sync with the music.
 */
- (void)initScrubberTimer
{
    CMTime playerItemDuration = [self playerItemDuration];
    
    // If the duration is not a valid time, do nothing and return.
    if (CMTIME_IS_INVALID(playerItemDuration)) {
        return;
    }
    
    // Default update interval.
    double interval = 0.1f;
    
    // Calculate an appropriate interval in seconds to update the scrubber control.
    double duration = CMTimeGetSeconds(playerItemDuration);
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth(self.scrubber.bounds);
        interval = 0.5f * duration / width;
    }
    
    // Cannot use self directly inside the block below. Will cause retain cycle.
    __weak MusicPlayerViewController *musicPlayerViewController = self;
    
    // Register as observer to be updated at given intervals.
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
                                                                  queue:dispatch_get_main_queue() 
                                                             usingBlock:
                         ^(CMTime time){
                             [musicPlayerViewController syncScrubber];
                         }];
}

/* Cancels the previously registered time observer. */
- (void)removePlayerTimeObserver
{
	if (self.timeObserver) {
		[self.player removeTimeObserver:self.timeObserver];
		self.timeObserver = nil;
	}
}

/* User begins dragging the music thumb control to scrub through the music. */
- (IBAction)beginScrubbing:(id)sender 
{
    // Save the player's current playback rate.
    self.restoreAfterScrubbingRate = self.player.rate;
    
    // Pause the playback while user is scrubbing.
    [self.player pause];
    
    // Remove previous time observer to prevent interrupting with user scrubbing.
    [self removePlayerTimeObserver];
}

/* User has released the music thumb control to stop scrubbing. */
- (IBAction)endScrubbing:(id)sender 
{
    // Re-register as observer to sync scrubber control to player.
    if (nil == self.timeObserver) {
        [self initScrubberTimer];
    }
    
    // Restore the player's playback rate.
    if (self.restoreAfterScrubbingRate) {
        self.player.rate = self.restoreAfterScrubbingRate;
        self.restoreAfterScrubbingRate = 0.0f;
    }
}

/* Set the player's current time to match the scrubber's position. */
- (IBAction)scrub:(id)sender 
{
    CMTime playerItemDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerItemDuration)) {
        return;
    }
    
    // Tell player to seek to current time as indicated on scrubber control.
    double duration = CMTimeGetSeconds(playerItemDuration);
    if (isfinite(duration)) {
        float minValue = [self.scrubber minimumValue];
        float maxValue = [self.scrubber maximumValue];
        float value = [self.scrubber value];
        
        // Calculate time from scrubber's value.
        double time = duration * (value - minValue) / (maxValue - minValue);
        [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
    }
}

@end

#pragma mark -
#pragma mark - Player Implementation

@implementation MusicPlayerViewController (Player)

/* Returns the duration of the AVPlayerItem. */
- (CMTime)playerItemDuration
{
    AVPlayerItem *thePlayerItem = [self.player currentItem];
    
    // Make sure player item's status is ready for play, so that the duration
    // property contains a valid value.
    if (AVPlayerItemStatusReadyToPlay == thePlayerItem.status) {
        return [thePlayerItem duration];
    }
    return kCMTimeInvalid;
}

/* Returns YES if user is currently scrubbing the music; NO otherwise. */
- (BOOL)isScrubbing
{
    // restoreAfterScrubbingRate is not zero only when user begins scrubbing.
    return (self.restoreAfterScrubbingRate != 0.0f);
}

/* Returns YES if the music player is playing; NO otherwise. */
- (BOOL)isPlaying
{
    // Player rate 0.0 means it has stopped.
    return ([self isScrubbing] || self.player.rate != 0.0f);
}

#pragma mark - Player Notifications

/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    // Hide the Pause button and show the Play button instead.
    [self showPlayButton];
    
    // Automatically reset playback time to beginning for user.
    [self.player seekToTime:kCMTimeZero];
}


#pragma mark - Error Handler

/*
 Shows an error message in an alert view. Error can be due to any of the
 following reasons:
 
 1. Values of asset's properties did not load successfully.
 2. Asset is not playable.
 3. Player item's status indicates an error.
 */
- (void)assetFailedToPrepareForPlayback:(NSError *)error
{
    // Clean up on error.
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disablePlayerControls];
    
    // Show the error object's details on an alert view.
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - Asset Properties Loaded Asynchronously

/*
 This method is invoked at the completion of loading of the values for all requested
 keys on the asset.
 Sets up an AVPlayerItem and AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVAsset *)asset withKeys:(NSArray *)requestedKeys
{
    // Make sure that the value of each property has loaded successfully.
	for (NSString *thisKey in requestedKeys) {
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        
		if (AVKeyValueStatusFailed == keyStatus) {
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
	}
    
    // Show the asset's metadata on the view.
    [self showMetadata:asset.commonMetadata];
        
    // Create a new AVPlayerItem from the successfully loaded AVAsset.
    self.playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
    
    // Observe the player item "status" property to determine when it is ready to play.
    [self.playerItem addObserver:self
                      forKeyPath:kStatusKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:MusicPlayerViewControllerPlayerItemStatusObserverContext];
    
    // When the player item has played to its end, we'll reset the
    // music player's controls.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    
    // Create a new AVPlayer from the AVPlayerItem.
    self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
}

#pragma mark - Asset Key-Value Observing

/*
 Called when the player's or player item's property values has changed.
 We want to sync the music player controls state to these property values.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    // AVPlayerItem "status" property value observer.
    if (context == MusicPlayerViewControllerPlayerItemStatusObserverContext) {
        [self syncPlayPauseButtons];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            // Player's status is unknown because no media resource is loaded
            // for playback yet.
            case AVPlayerStatusUnknown: {
                // Reset and disable the music player controls. We'll enable
                // the controls when player item is ready to play.
                [self removePlayerTimeObserver];
                [self syncScrubber];
                [self disablePlayerControls];
                break;
            }
                
            // Once the AVPlayerItem is ready to play, the duration property has a
            // value that we can retrieve.
            case AVPlayerStatusReadyToPlay: {
                // Enable the music player controls, since the music is now ready
                // to play.
                [self enablePlayerControls];
                
                // Start synchronizing the scrubber UI with the music playing by
                // registering ourselves as an observer.
                [self initScrubberTimer];
                
                break;
            }
                
            // Show error message to user on failure.
            case AVPlayerStatusFailed: {
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
                break;
            }
        }
    }
    // Default to super class's default key-value observer handler.
    else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

@end
