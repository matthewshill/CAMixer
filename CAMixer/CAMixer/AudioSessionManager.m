//
//  AudioSessionManager.m
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import "AudioSessionManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioSessionManager

+(AudioSessionManager*)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static AudioSessionManager * _sharedManager = nil;
    
    dispatch_once(&pred, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

-(void)setupAudioSession {
    AVAudioSession * sessionInstance = [AVAudioSession sharedInstance];
    
    NSError *error = nil;
    
    [sessionInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
    if(error != nil) {
        NSLog(@"Error setting audio category: %@", error.localizedDescription);
    }
    
    NSTimeInterval bufferDuration = .005;
    [sessionInstance setPreferredIOBufferDuration:bufferDuration error:&error];
    if(error != nil) {
        NSLog(@"Error setting Preferred Buffer Duration: %@", error.localizedDescription);
    }
    
    [sessionInstance setPreferredSampleRate:44100.0 error:&error];
    if(error !=nil) {
        NSLog(@"Error setting preferred sample rate: %@", error.localizedDescription);
    }
    
    //Interruption Handler
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:sessionInstance];
    //Route ChangeHandler
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handeRouteChange:) name:AVAudioSessionRouteChangeNotification object:sessionInstance];
    
    [sessionInstance setActive:YES error:&error];
    if(error != nil) {
        NSLog(@"Error setting audio session to active: %@", error.localizedDescription);
    } else {
        NSLog(@"AVAudioSession set to active");
    }
    
}

-(void)handleInterruption:(NSNotification *)notificaiton {
    UInt8 interruptionType = [[notificaiton.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    NSLog(@"AVAudioSession interrupted: %@", interruptionType == AVAudioSessionInterruptionTypeBegan ? @"Begin Interruption" : @"End Interruption");
    
    if(interruptionType == AVAudioSessionInterruptionTypeBegan) {
        //stop for the interruption
        //Tell Audio Manager to stop playing
        [[NSNotificationCenter defaultCenter] postNotificationName:@"StopAudioNotification" object:nil];
    }
    else if(interruptionType == AVAudioSessionInterruptionTypeEnded) {
        NSError *error = nil;
        
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if(error != nil) {
            NSLog(@"AVAudioSession setActive failed: %@", error.localizedDescription);
        }
    }
}

-(void)handleRouteChange:(NSNotification *)notificaiton{
    UInt8 reasonVal = [[notificaiton.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    NSLog(@"handleRouteChange: reason value: %d", reasonVal);
    
    AVAudioSessionRouteDescription * routeDescription = [notificaiton.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    NSLog(@"handleRouteChange: new route: %@", routeDescription);
}

@end
