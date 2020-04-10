//
//  RTCData.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/23.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MSMediaKind) {
    MSMediaKindUnknow,
    MSMediaKindAudio,
    MSMediaKindVideo
};

NS_ASSUME_NONNULL_BEGIN

@interface RTCData : NSObject
@property (nonatomic, assign, readonly) NSInteger dataID;
@property (nonatomic, strong, readonly) NSString *idStr;
@property (nonatomic, strong, readonly) NSString *codec;
@property (nonatomic, strong, readonly) NSString *source;
@property (nonatomic, assign, readonly) MSMediaKind kind;
@property (nonatomic, strong, readonly) RTCMediaStreamTrack *track;

@property (nonatomic, assign) BOOL locallyPaused;
@property (nonatomic, assign) BOOL remotelyPaused;

- (instancetype)init:(NSInteger)dataID track:(RTCMediaStreamTrack *)track source:(NSString *)source codec:(NSString *)codec;

- (NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
