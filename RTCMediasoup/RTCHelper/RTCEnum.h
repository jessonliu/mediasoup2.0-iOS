//
//  RTCEnum.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/5/8.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#ifndef RTCEnum_h
#define RTCEnum_h


typedef NS_ENUM(NSInteger, MSMediaKind) {
    MSMediaKindUnknow,
    MSMediaKindAudio,
    MSMediaKindVideo
};

/**
  媒体数据源类型
 */
typedef NS_ENUM(NSInteger, MediaSourceType) {
    MediaSourceTypeUnknow = 1, // 未知
    MediaSourceTypeMic,        // 麦克风
    MediaSourceTypeCam,        // 摄像头
    MediaSourceTypeScreen      // 屏幕
};

#endif /* RTCEnum_h */
