//
//  SDLBinaryAudioManager.h
//  SmartDeviceLink-Example
//
//  Created by Joel Fischer on 10/24/17.
//  Copyright © 2017 smartdevicelink. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SDLAudioFile;
@class SDLManager;
@class SDLStreamingMediaLifecycleManager;
@protocol SDLStreamingAudioManagerType;
@protocol SDLAudioStreamManagerDelegate;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SDLErrorDomainAudioStreamManager;

@interface SDLAudioStreamManager : NSObject

@property (weak, nonatomic) id<SDLAudioStreamManagerDelegate> delegate;

@property (assign, nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (copy, nonatomic, readonly) NSArray<SDLAudioFile *> *queue;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithManager:(id<SDLStreamingAudioManagerType>)streamManager NS_DESIGNATED_INITIALIZER;

/**
 Push a new file URL onto the queue after converting it into the correct PCM format for streaming binary data.

 @note This happens on a global background thread and will provide an error callback using the delegate if the conversion fails.

 @param fileURL File URL to convert
 */
- (void)pushWithFileURL:(NSURL *)fileURL;

/**
 Play the next item in the queue. If an item is currently playing, it will continue playing and this item will begin playing after it is completed. If all items are playing via `playAll`, this will do nothing.

 When complete, this will callback on the delegate.
 */
- (void)playNextWhenReady;

/**
 Stop playing the queue after the current item completes and clear the queue. If nothing is playing, the queue will be cleared.
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
