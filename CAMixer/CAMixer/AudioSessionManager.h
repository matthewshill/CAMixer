//
//  AudioSessionManager.h
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioSessionManager : NSObject

+(AudioSessionManager*)sharedInstance;

-(void)setupAudioSession;

@end
