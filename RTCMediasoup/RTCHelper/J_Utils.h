//
//  J_Utils.h
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface J_Utils : NSObject

/*
 *生成UUID
 */
+ (NSString *)UUIDString;

/**
 获取八位随机数

 @return 数组
 */
+ (int)getRandomEightDigitNumber;


/**
 获取随机数
 to > from
 @param from 从一个数字开始
 @param to 到另一个数字结束
 @return 随机数
 */
+ (int)getRandomNumber:(int)from to:(int)to;

/**
 字典转JSON 字符串

 @param dict 字典
 @param isDeleNewline 是否删除换行
 @param isDeleEmpty 是否删除空格
 @return json 字符串
 */
+ (NSString *)jsonStringWithDict:(NSDictionary *)dict isDeleNewline:(BOOL)isDeleNewline isDeleEmpty:(BOOL)isDeleEmpty;



+ (NSDictionary *)extractRtpCapabilities:(NSString *)nativeSdp;

+ (NSDictionary *)sdpTransportToDictionary:(NSString *)nativeSdp;

+ (NSString *)transportToNativeSdp:(NSDictionary *)sdpObj;

@end

NS_ASSUME_NONNULL_END
