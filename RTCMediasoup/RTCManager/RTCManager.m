//
//  RTCManager.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/15.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "RTCManager.h"
#import "J_Utils.h"
#import "VideoCaptureController.h"
#import "RTCMediaStreamTrack+React.h"


@interface RTCManager ()

@property (nonatomic, strong) RTCPeerConnectionFactory *rtc_connection_factory;

@end

@implementation RTCManager


+ (instancetype)shareInstance:(BOOL)isFont resolution:(RTCResolution)resolution {
    RTCManager *manager = [RTCManager new];
    manager.isFront = isFont;
    manager.resolution = resolution;
    return manager;
}


#pragma mark - Getter
- (RTCPeerConnectionFactory *)rtc_connection_factory {
    if (!_rtc_connection_factory) {
        self.rtc_connection_factory = [[RTCPeerConnectionFactory alloc] init];
    }
    return _rtc_connection_factory;
}

- (RTCAudioTrack *)localAudioTrack {
    if (!_localAudioTrack) {
        self.localAudioTrack = [self.rtc_connection_factory audioTrackWithTrackId:[J_Utils UUIDString]];
    }
    return _localAudioTrack;
}

- (RTCVideoTrack *)localVideoTrack {
    RTCVideoSource *videoSource =  [self.rtc_connection_factory videoSource];
    _localVideoTrack            = [self.rtc_connection_factory videoTrackWithSource:videoSource trackId:[J_Utils UUIDString]];
    NSDictionary *para = self.constraints[@"video"];
    RTCCameraVideoCapturer *videoCapturer           = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
    VideoCaptureController *videoCaptureController  = [[VideoCaptureController alloc] initWithCapturer:videoCapturer andConstraints:para];
    JFLog(@"当前分辨率: %@", para);
    _localVideoTrack.videoCaptureController         = videoCaptureController;
    
    [videoCaptureController startCapture];
    
    return _localVideoTrack;
}

- (void)setIsFront:(BOOL)isFront {
    if (isFront != _isFront) {
        _isFront = isFront;
    }
}


- (NSDictionary *)constraints {
    return @{
             @"video":@{
                     @"mandatory":@{@"minWidth":       self.getResoConfig(self.resolution, 0),
                                    @"minHeight":      self.getResoConfig(self.resolution, 1),
                                    @"minFrameRate":   self.getResoConfig(self.resolution, 2)},
                     @"facingMode": _isFront ? @"user" : @"environment"
                     }
             };
}
    


- (NSNumber*(^)(RTCResolution, NSInteger))getResoConfig {
    return ^(RTCResolution resolution, NSInteger idx) {
        return @[@[@(192),  @(144),  @(15)],
                 @[@(480),  @(360),  @(25)],
                 @[@(960),  @(540),  @(25)],
                 @[@(1280), @(720),  @(30)],
                 @[@(1920), @(1080), @(30)]
                 ][resolution][idx];
    };
}

- (NSArray <NSNumber *>*)getBps {
    CGFloat w = [self.getResoConfig(self.resolution, 0) integerValue];
    CGFloat h = [self.getResoConfig(self.resolution, 1) integerValue];
    CGFloat minBps = MIN(w, h) * 1024;
    CGFloat curBps = (w + h) / 2 * 1024;
    CGFloat maxBps = MAX(w, h) * 1024;
    return @[@(minBps), @(curBps), @(maxBps)];
}

- (void)setResolution:(RTCResolution)resolution {
    if (_resolution != resolution) {
        _resolution = resolution;
    }
}

- (void)dealloc {
}

@end
