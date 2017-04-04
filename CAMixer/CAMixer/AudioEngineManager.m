//
//  AudioEngineManager.m
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import "AudioEngineManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioEngineManager {
    AVAudioEngine * audioEngine;
    AVAudioPlayerNode * inputGuitarPlayerNode;
    AVAudioPlayerNode * inputDrumsPlayerNode;
    BOOL mIsPlaying;
}

-(BOOL)isPlaying {
    return mIsPlaying;
}

-(id)init {
    self = [super init];
    if (self != nil) {
        mIsPlaying = NO;
    }
    
    return self;
}

-(void)load {
    [self loadEngine];
}

-(void)loadEngine {
    audioEngine = [[AVAudioEngine alloc] init];
    
    inputGuitarPlayerNode = [[AVAudioPlayerNode alloc] init];
    [audioEngine attachNode:inputGuitarPlayerNode];
    
    //Load the audio file
    NSURL * guitarFileUrl = [[NSBundle mainBundle] URLForResource:@"GuitarMonoSTP" withExtension:@"aif"];
    NSError * error = nil;
    
    AVAudioFile * guitarFile = [[AVAudioFile alloc] initForReading:guitarFileUrl error:&error];
    if(error != nil) {
        NSLog(@"Error loading file: %@", error.localizedDescription);
        return;
    }
    
    AVAudioPCMBuffer *guitarBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:guitarFile.processingFormat frameCapacity:(UInt32)guitarFile.length];
    [guitarFile readIntoBuffer:guitarBuffer error:&error];
    if(error != nil) {
        NSLog(@"Error loading file into buffer: %@", error.localizedDescription);
        return;
    }
    
    //Create a player node for the drums
    inputDrumsPlayerNode = [[AVAudioPlayerNode alloc] init];
    [audioEngine attachNode:inputDrumsPlayerNode];
    
    //Load the audio file
    NSURL *drumsFileUrl = [[NSBundle mainBundle] URLForResource:@"DrumsMonoSTP" withExtension:@"aif"];
    
    AVAudioFile *drumsFile = [[AVAudioFile alloc] initForReading:drumsFileUrl error:&error];
    if (error != nil) {
        NSLog(@"Error loading file: %@", error.localizedDescription);
        return;
    }
    
    AVAudioPCMBuffer *drumsBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:drumsFile.processingFormat frameCapacity:(UInt32)drumsFile.length];
    [drumsFile readIntoBuffer:drumsBuffer error:&error];
    if(error != nil) {
        NSLog(@"Error loading drums file into buffer: %@", error.localizedDescription);
        return;
    }
    
    AVAudioMixerNode *mainMixerNode = [audioEngine mainMixerNode];
    [audioEngine connect:inputGuitarPlayerNode to:mainMixerNode format:guitarBuffer.format];
    [audioEngine connect:inputDrumsPlayerNode to:mainMixerNode format:drumsBuffer.format];
    
    [inputGuitarPlayerNode scheduleBuffer:guitarBuffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    [inputDrumsPlayerNode scheduleBuffer:drumsBuffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    
    [inputGuitarPlayerNode setPan:-1];
    [inputDrumsPlayerNode setPan:1.0];
}

-(void)startPlaying {
    NSError * error = nil;
    [audioEngine startAndReturnError:&error];
    
    [inputGuitarPlayerNode play];
    [inputDrumsPlayerNode play];
    
    mIsPlaying = YES;
}

-(void)stopPlaying {
    //Stop the audio player
    [audioEngine pause];
    mIsPlaying = NO;
}

-(void)setGuitarInputVolume:(Float32)value {
    inputGuitarPlayerNode.volume = value;
}

-(void)setDrumInputVolume:(Float32)value {
    inputDrumsPlayerNode.volume = value;
}

-(Float32*)guitarFrequencyDataOfLength:(UInt32 *)size {
    *size = 0;
    return NULL;
}

-(Float32*)drumsFrequencyDataOfLength:(UInt32 *)size {
    *size = 0;
    return NULL;
}
@end
