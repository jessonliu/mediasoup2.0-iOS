//
//  RTCData.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/23.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "RTCData.h"

@implementation RTCData
@synthesize dataID  = _dataID;
@synthesize idStr   = _idStr;
@synthesize kind    = _kind;
@synthesize track   = _track;
@synthesize source  = _source;
@synthesize codec   = _codec;

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    return @{@"dataID":@"id"};
}

- (instancetype)init:(NSInteger)dataID track:(RTCMediaStreamTrack *)track source:(NSString *)source codec:(NSString *)codec {
    self = [super init];
    if (self) {
        self.dataID = dataID;
        self.track = track;
        self.source = source;
        self.codec = codec;
    }
    
    return self;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *mul_dic = [self mj_keyValues];
    if (self.track) [mul_dic setObject:self.track forKey:@"track"];
    return mul_dic;
}


#pragma mark - Setter
- (void)setDataID:(NSInteger)dataID {
    _dataID = dataID;
    self.idStr = [NSString stringWithFormat:@"%ld", _dataID];
}

- (void)setIdStr:(NSString * _Nonnull)idStr {
    _idStr = idStr;
}

- (void)setKind:(MSMediaKind)kind {
    _kind = kind;
}

- (void)setTrack:(RTCMediaStreamTrack * _Nonnull)track {
    _track = track;
}

- (void)setSource:(NSString * _Nonnull)source {
    _source = source;
}

- (void)setCodec:(NSString * _Nonnull)codec {
    _codec = codec;
}

#pragma mark - Getter
- (NSInteger)dataID {
    return _dataID;
}

- (NSString *)idStr {
    return _idStr;
}

- (MSMediaKind)kind {
    if ([self.track.kind isEqualToString:@"audio"]) {
        return MSMediaKindAudio;
    }
    
    if ([self.track.kind isEqualToString:@"video"]) {
        return MSMediaKindVideo;
    }
    return MSMediaKindUnknow;
}

- (NSString *)source {
    return _source;
}

- (NSString *)codec {
    return _codec;
}

@end
