//
//  CAManager.m
//  CAMixer
//
//  Created by Matthew S. Hill on 3/30/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import "CAManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>

const Float64 kSampleRate = 44100.0;
const UInt32 frequencyDataLength = 256;

typedef struct {
    AudioStreamBasicDescription asbd;
    Float32 *data;
    UInt32 numberOfFrames;
    UInt32 sampleNumber;
    Float32 *frequencyData;
} SoundBuffer, *SoundBufferPtr;

@interface CAManager() {
    SoundBuffer mSoundBuffer[2];
    AVAudioFormat *mAudioFormat;
    
    AUGraph mGraph;
    AudioUnit mMixer;
    AudioUnit mOutput;
    
    BOOL mIsPlaying;
}

@end

@implementation CAManager

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

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    
    DisposeAUGraph(mGraph);
    
    free(mSoundBuffer[0].data);
    free(mSoundBuffer[1].data);
    free(mSoundBuffer[0].frequencyData);
    free(mSoundBuffer[1].frequencyData);
    
    //clear the SoundBuffer
    memset(&mSoundBuffer, 0, sizeof(mSoundBuffer));
}

-(void)load {
    [self loadAudioFiles];
    [self initializeAUGraph];
}

-(void)loadAudioFiles {
    NSLog(@"loadAudioFiles");
    NSString * guitarSourcePath = [[NSBundle mainBundle] pathForResource:@"GuitarMonoSTP" ofType:@"aif"];
    NSString * drumsSourcePath = [[NSBundle mainBundle] pathForResource:@"DrumsMonoSTP" ofType:@"aif"];
    
    NSArray * sourcePaths = @[guitarSourcePath, drumsSourcePath];
    
    AVAudioFormat * audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kSampleRate channels:1 interleaved:YES];
    
    //loop through source paths and load files
    for (int i = 0; i<sourcePaths.count; i++) {
        NSString *sourcePath = sourcePaths[i];
        CFURLRef fileUrlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)sourcePath, kCFURLPOSIXPathStyle, false);
        
        //open file
        ExtAudioFileRef extAFref = 0;
        OSStatus result = ExtAudioFileOpenURL(fileUrlRef, &extAFref);
        if(result != 0 || !extAFref) {
            NSLog(@"Error opening audio file. ExtAudioFileOpenURL result: %ld ", (long)result);
            break;
        }
        
        //get file data format
        AudioStreamBasicDescription audioFileFormat;
        UInt32 propertySize = sizeof(audioFileFormat);
        
        result = ExtAudioFileGetProperty(extAFref, kExtAudioFileProperty_FileDataFormat, &propertySize, &audioFileFormat);
        if(result != 0) {
            NSLog(@"Error getting file format property.ExtAudioFileGetProperty result: %ld", (long)result);
            break;
        }
        
        //Set the format that will be sent to the input of the mixer
        
        double sampleRateRatio = kSampleRate / audioFileFormat.mSampleRate;
        
        propertySize = sizeof(AudioStreamBasicDescription);
        
        result = ExtAudioFileSetProperty(extAFref, kExtAudioFileProperty_ClientDataFormat, propertySize, audioFormat.streamDescription);
        if(result != 0){
            NSLog(@"Error setting audio format property. ExtAudioFileSetProperty result: %ld ", (long)result);
        }
        
        //Get the file length in frames
        UInt64 numOfFrames = 0;
        propertySize = sizeof(numOfFrames);
        
        result = ExtAudioFileGetProperty(extAFref, kExtAudioFileProperty_FileLengthFrames, &propertySize, &numOfFrames);
        if (result !=0) {
            NSLog(@"Error getting number of frames. ExtAudioFileGetProperty result: %ld", (long)result);
            break;
        }
        
        //print number of frames and a converted number of frames based on the sample ratio
        NSLog(@"%u frames in %@", (unsigned int)numOfFrames, sourcePath.lastPathComponent);
        
        numOfFrames = numOfFrames * sampleRateRatio;
        NSLog(@"%u frames after sample ratio multiplied in %@", (unsigned int)numOfFrames, sourcePath.lastPathComponent);
        
        //Set up the sound buffer
        mSoundBuffer[i].numberOfFrames = (UInt32)numOfFrames;
        mSoundBuffer[i].asbd = *(audioFormat.streamDescription);
        
        //Determine the number of samples by multiplying the number of frames by the number of channels per frame
        UInt32 samples = (UInt32)numOfFrames * mSoundBuffer[i].asbd.mChannelsPerFrame;
        
        //Allocate memory for a buffer size based on the number of samples
        mSoundBuffer[i].data = (Float32 *)calloc(samples, sizeof(Float32));
        mSoundBuffer[i].sampleNumber = 0;
        
        mSoundBuffer[i].frequencyData = (Float32 *)calloc(frequencyDataLength, sizeof(Float32));
        
        //Create an AudioBufferList to read into
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = 1;
        bufferList.mBuffers[0].mData = mSoundBuffer[i].data;
        bufferList.mBuffers[0].mDataByteSize = samples * sizeof(Float32);
        
        //read audio data from file into allocated data buffer
        
        //Number of packets is the same as the number of frames we've extraced and calulcated based on sample ratio
        UInt32 numOfPackets = (UInt32)numOfFrames;
        
        result = ExtAudioFileRead(extAFref, &numOfPackets, &bufferList);
        if(result != 0) {
            NSLog(@"Error reading audio file. ExtAudioFileRead result: %ld", (long)result);
            free(mSoundBuffer[i].data);
            mSoundBuffer[i].data = 0;
        }
        
        //Dispose the audio file reference now that is has been read
        ExtAudioFileDispose(extAFref);
        
        //Release the reference to the file url
        CFRelease(fileUrlRef);
    }
}

-(void)initializeAUGraph {
    NSLog(@"Initializing AUGraph...");
    
    //Create the AUNodes
    AUNode outputNode;
    AUNode mixerNode;
    
    //Setup the audio format for the graph
    mAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kSampleRate channels:2 interleaved:NO];
    
    OSStatus result = 0;
    
    result = NewAUGraph(&mGraph);
    if(result != 0) {
        NSLog(@"Error creating new AUGraph: %ld", (long)result);
        return;
    }
    
    //create two AudioCompenetDescriptions for the AUs we want in the graph
    
    //Output audio unit
    AudioComponentDescription outputDescription;
    outputDescription.componentType = kAudioUnitType_Output;
    outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputDescription.componentFlags = 0;
    outputDescription.componentFlagsMask = 0;
    
    //Multichannel mixer audio unit
    AudioComponentDescription mixerDescription;
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerDescription.componentFlags = 0;
    mixerDescription.componentFlagsMask = 0;
    
    //Begin to add nodes
    result = AUGraphAddNode(mGraph, &outputDescription, &outputNode);
    if(result != 0){
        NSLog(@"Error adding output node: AUGraphAddNode reuslt: %ld", (long)result);
        return;
    }
    
    result = AUGraphAddNode(mGraph, &mixerDescription, &mixerNode);
    if (result != 0) {
        NSLog(@"Error adding mixer node: AUGraphAddNode result: %ld", (long)result);
        return;
    }
    
    //connect node input
    result = AUGraphConnectNodeInput(mGraph, mixerNode, 0, outputNode, 0);
    if (result != 0) {
        NSLog(@"Error connecting node input: AUGRaphConnectNodeInput result: %ld", (long)result);
        return;
    }
    
    //Open the AudioUnits via the graph
    result = AUGraphOpen(mGraph);
    if (result != 0) {
        NSLog(@"Error opening graph: AUGraphOpen result: %ld", (long)result);
        return;
    }
    
    result = AUGraphNodeInfo(mGraph, mixerNode, NULL, &mMixer);
    if(result != 0) {
        NSLog(@"Error loading mixer node info: AUGraphNodeInfo result: %ld", (long)result);
        return;
    }
    
    result = AUGraphNodeInfo(mGraph, outputNode, NULL, &mOutput);
    if(result != 0) {
        NSLog(@"Error loading output ndoe info: AUGraphNodeInfo: %ld", (long)result);
        return;
    }
    
    //Setup 2 buses
    UInt32 numbuses = 2;
    
    result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    if(result != 0) {
        NSLog(@"Error setting audio unit property on mixer: %ld", (long)result);
        return;
    }
    
    for (int i = 0; i < numbuses; ++i) {
        //setup render callback
        AURenderCallbackStruct renderCallbackStruct;
        renderCallbackStruct.inputProc = &renderAudioInput;
        renderCallbackStruct.inputProcRefCon = mSoundBuffer;
        
        //Set a callback for the specified node's input
        result = AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &renderCallbackStruct);
        if(result != 0){
            NSLog(@"AUGrapgSetNodeInputCallback failed with result: %ld", (long)result);
            return;
        }
        
        //Set the input stream format property
        result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
        if(result != 0) {
            NSLog(@"AudioUnitSetProperty fialed with result: %ld", (long)result);
            return;
        }
    }
    
    //Set the output stream format property
    result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
    if(result !=0) {
        NSLog(@"AudioUnitSetProperty mixer stream format failed with result: %ld", (long)result);
        return;
    }
    
    //Initialize the graph
    result = AUGraphInitialize(mGraph);
    if(result != 0){
        NSLog(@"AUGraphInitialize failed with result: %ld", (long)result);
        return;
    }
    
}

-(void)startPlaying {
    OSStatus result = AUGraphStart(mGraph);
    if(result != 0) {
        NSLog(@"AUGraphInitialize failed with result: %ld", (long)result);
        return;
    }
    
    mIsPlaying = YES;
}

-(void)stopPlaying {
    Boolean isRunning = false;
    OSStatus result = AUGraphIsRunning(mGraph, &isRunning);
    
    if(result != 0) {
        NSLog(@"AUGraphIsRunning failed: %ld", (long)result);
        return;
    }
    
    if(isRunning) {
        result = AUGraphStop(mGraph);
        if(result != 0) {
            NSLog(@"AUGraphStop failed: %ld", (long)result);
            return;
        }
        mIsPlaying = NO;
        
    } else {
        NSLog(@"AUGraphIsRunning reported not running.");
    }
}

-(void)setVolumeForInput:(UInt32)inputIndex value:(AudioUnitParameterValue)value {
    OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputIndex, value, 0);
    if(result != 0) {
        NSLog(@"AudioUnitSetParameter fialed when setting input volume: %ld", (long)result);
        return;
    }
}

-(void)setGuitarInputVolume:(Float32)value{
    [self setVolumeForInput:0 value:value];
}

-(void)setDrumInputVolume:(Float32)value {
    [self setVolumeForInput:1 value:value];
}

-(Float32*)guitarFrequencyDataOfLength:(UInt32 *)size {
    *size = frequencyDataLength;
    return mSoundBuffer[0].frequencyData;
}

-(Float32*)drumsFrequencyDataOfLength:(UInt32 *)size {
    *size = frequencyDataLength;
    return mSoundBuffer[1].frequencyData;
}

//Static audio render method callback
static OSStatus renderAudioInput(void *inRefCon, AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberOfFrames, AudioBufferList *ioData)
{
    SoundBufferPtr soundBuffer = (SoundBufferPtr)inRefCon;
    
    UInt32 sample = soundBuffer[inBusNumber].sampleNumber;
    UInt32 startSample = sample;
    UInt32 bufferTotalSamples = soundBuffer[inBusNumber].numberOfFrames;
    
    //reference to the input data buffer
    Float32 *inputData = soundBuffer[inBusNumber].data;//audio data buffer
    //references to the channel buffer
    Float32 *outLeft = (Float32 *)ioData->mBuffers[0].mData;
    Float32 *outRight = (Float32 *)ioData->mBuffers[1].mData;
    
    //Loop thru the number of frames and set the output data from the input data
    //Use the left channel for bus 0 (guitar) and right channel for bus 1(drums) to distinguish for example
    for (int i = 0; i < inNumberOfFrames; ++i) {
        if(inBusNumber == 0) {
            outLeft[i] = inputData[sample++];
            outRight[i] = 0;
        } else {
            outLeft[i] = 0;
            outRight[i] = inputData[sample++];
        }
        
        if(sample > bufferTotalSamples) {
            sample = 0;
            NSLog(@"Starting over at from 0 for bus %d", (int)inBusNumber);
        }
    }
    
    soundBuffer[inBusNumber].sampleNumber = sample;
    performFFT(&inputData[startSample], inNumberOfFrames, soundBuffer, inBusNumber);
    
    return noErr;
    
}

static void performFFT(float* data, UInt32 numberOfFrames, SoundBufferPtr soundBuffer, UInt32 inBusNumber) {
    int bufferLog2 = round(log(numberOfFrames));
    float fftNormFactor = 1.0/(2 * numberOfFrames);
    
    FFTSetup fftSetup = vDSP_create_fftsetup(bufferLog2, kFFTRadix2);
    
    int numberOfFramesOver2 = numberOfFrames / 2;
    float outReal[numberOfFramesOver2];
    float outImaginary[numberOfFramesOver2];
    
    COMPLEX_SPLIT output = {.realp = outReal, .imagp = outImaginary};
    
    vDSP_ctoz((COMPLEX *)data, 2, &output, 1, numberOfFramesOver2);
    
    //Use FFT Forward for standard PCM audio
    vDSP_fft_zrip(fftSetup, &output, 1, bufferLog2, FFT_FORWARD);
    
    //Scale the FFT data
    vDSP_vsmul(output.realp, 1, &fftNormFactor, output.realp, 1, numberOfFramesOver2);
    vDSP_vsmul(output.imagp, 1, &fftNormFactor, output.imagp, 1, numberOfFramesOver2);
    
    //Take the absolute value of the output to get in range of 0 to 1
    vDSP_zvabs(&output, 1, soundBuffer[inBusNumber].frequencyData, 1, numberOfFramesOver2);
    
    vDSP_destroy_fftsetup(fftSetup);
    
}
@end
