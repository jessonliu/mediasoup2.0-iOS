//
//  RTCManager.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/15.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, RTCResolution) {
    RTCResolution_144P,
    RTCResolution_360P,
    RTCResolution_540P,
    RTCResolution_720P,
    RTCResolution_1080P
};

@interface RTCManager : NSObject

@property (nonatomic,strong) RTCAudioTrack* localAudioTrack;

@property (nonatomic,strong) RTCVideoTrack* localVideoTrack;

@property(nonatomic,strong) RTCCameraVideoCapturer* capturer;

+ (instancetype)shareInstance:(BOOL)isFont resolution:(RTCResolution)resolution;

@property (nonatomic, assign) BOOL isFront;

@property (nonatomic, assign) RTCResolution resolution;

- (NSArray <NSNumber *>*)getBps;


@end

NS_ASSUME_NONNULL_END
