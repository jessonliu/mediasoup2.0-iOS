
#import <WebRTC/RTCMediaStreamTrack.h>

@class VideoCaptureController;
@interface RTCMediaStreamTrack (React)

@property (strong, nonatomic) VideoCaptureController *videoCaptureController;

- (void)stop;

@end
