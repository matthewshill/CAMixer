//
//  AudioEngineManager.h
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioManager.h"

@interface AudioEngineManager : NSObject <AudioManager>

-(void)loadEngine;
-(void)startPlaying;

-(void)setGuitarInputVolume:(Float32)value;
-(void)setDrumInputVolume:(Float32)value;

@end
