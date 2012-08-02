//
//  MusicPlayerViewController.h
//  TCMusicPlayer
//
//  Created by Lee Tze Cheun on 7/24/12.
//  Copyright (c) 2012 TC Lee. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/**
 * Controller class for the music player.
 *
 * The music player view provides UI controls to play, pause and seek.
 */
@interface MusicPlayerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *albumImageView;
@property (weak, nonatomic) IBOutlet UILabel *songLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UILabel *albumLabel;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;

// Play and Pause buttons must have a strong reference because they'll be
// swapped in and out at runtime. If we use a weak reference, once either
// button is swapped out it will be deallocated.
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *pauseButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *activityIndicatorButton;
@property (weak, nonatomic) IBOutlet UISlider *scrubber;

/* Play and pause the music. */
- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;

/* User drags the scrubber control to seek. */
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;

@end
