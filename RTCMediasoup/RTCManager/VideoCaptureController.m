
#import "VideoCaptureController.h"

static int DEFAULT_WIDTH  = 320;
static int DEFAULT_HEIGHT = 240;
static int DEFAULT_FPS    = 20;


@implementation VideoCaptureController {
    RTCCameraVideoCapturer *_capturer;
    NSString *_sourceId;
    BOOL _usingFrontCamera;
    CGFloat _width;
    CGFloat _height;
    CGFloat _fps;
}

-(instancetype)initWithCapturer:(RTCCameraVideoCapturer *)capturer
                 andConstraints:(NSDictionary *)constraints {
    self = [super init];
    if (self) {
        _capturer = capturer;

        // Default to the front camera.
        _usingFrontCamera = YES;

        // Check the video contraints: examine facingMode and sourceId
        // and pick a default if neither are specified.
        id facingMode           = constraints[@"facingMode"];
        id mandatory            = constraints[@"mandatory"];
        id optionalConstraints  = constraints[@"optional"];
        
        if (mandatory) {
            _width  = [mandatory[@"minWidth"] floatValue] ? : DEFAULT_WIDTH;
            _height = [mandatory[@"minHeight"] floatValue] ? : DEFAULT_HEIGHT;
            _fps    = [mandatory[@"minFrameRate"] floatValue] ? : DEFAULT_FPS;
        }

        if (facingMode && [facingMode isKindOfClass:[NSString class]]) {
            AVCaptureDevicePosition position;
            if ([facingMode isEqualToString:@"environment"]) {
                position = AVCaptureDevicePositionBack;
            } else if ([facingMode isEqualToString:@"user"]) {
                position = AVCaptureDevicePositionFront;
            } else {
                // If the specified facingMode value is not supported, fall back
                // to the front camera.
                position = AVCaptureDevicePositionFront;
            }

            _usingFrontCamera = position == AVCaptureDevicePositionFront;
        } else if (optionalConstraints && [optionalConstraints isKindOfClass:[NSArray class]]) {
            NSArray *options = optionalConstraints;
            for (id item in options) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    NSString *sourceId = ((NSDictionary *)item)[@"sourceId"];
                    if (sourceId && sourceId.length > 0) {
                        _sourceId = sourceId;
                        break;
                    }
                }
            }
        }
    }

    return self;
}

-(void)startCapture {
    AVCaptureDevice *device;
    if (_sourceId) {
        device = [AVCaptureDevice deviceWithUniqueID:_sourceId];
    }
    if (!device) {
        AVCaptureDevicePosition position
            = _usingFrontCamera
                ? AVCaptureDevicePositionFront
                : AVCaptureDevicePositionBack;
        device = [self findDeviceForPosition:position];
    }

    // TODO: Extract width and height from constraints.
    AVCaptureDeviceFormat *format
        = [self selectFormatForDevice:device
                      withTargetWidth:_width
                     withTargetHeight:_height];
    if (!format) {
        JFErrorLog(@"[VideoCaptureController] No valid formats for device %@", device);

        return;
    }

    // TODO: Extract fps from constraints.
    [_capturer startCaptureWithDevice:device format:format fps:_fps];

    JFLog(@"[VideoCaptureController] Capture started");
}

-(void)stopCapture {
    
    [_capturer stopCapture];

    JFLog(@"[VideoCaptureController] Capture stopped");
}

-(void)switchCamera {
    _usingFrontCamera = !_usingFrontCamera;

    [self startCapture];
}

#pragma mark Private

- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            return device;
        }
    }

    return captureDevices[0];
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device
                                 withTargetWidth:(int)targetWidth
                                withTargetHeight:(int)targetHeight {
    NSArray<AVCaptureDeviceFormat *> *formats =
    [RTCCameraVideoCapturer supportedFormatsForDevice:device];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;

    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == [_capturer preferredOutputPixelFormat]) {
            selectedFormat = format;
        }
    }

    return selectedFormat;
}

@end
