//
//  CAManager.h
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioManager.h"

extern const Float64 kSampleRate;

@interface CAManager : NSObject<AudioManager>

-(void)loadAudioFiles;
-(void)initializeAUGraph;

-(void)startPlaying;
-(void)stopPlaying;

-(void)setGuitarInputVolume:(Float32)value;
-(void)setDrumInputVolume:(Float32)value;

-(Float32*)guitarFrequencyDataOfLength:(UInt32*)size;
-(Float32*)drumsFrequencyDataOfLength:(UInt32*)size;

@end
