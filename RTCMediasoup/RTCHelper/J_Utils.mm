//
//  J_Utils.m
//  WebRtcRoomIOS
//
//  Created by 刘金丰 on 2019/1/17.
//  Copyright © 2019 wjr. All rights reserved.
//

#import "J_Utils.h"
#import "SdpUtils.hpp"



@implementation J_Utils
/*
 *生成UUID
 */
+ (NSString *)UUIDString {
    CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
    CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
    CFRelease(uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
    CFRelease(uuid_string_ref);
    return uuid;
}

+ (int)getRandomEightDigitNumber {
    return [J_Utils getRandomNumber:10000000 to:99999999];
}

+ (int)getRandomNumber:(int)from to:(int)to {
    return from + arc4random() % (to - from + 1);
}


+ (NSString *)jsonStringWithDict:(NSDictionary *)dict isDeleNewline:(BOOL)isDeleNewline isDeleEmpty:(BOOL)isDeleEmpty {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    
    NSString *jsonString;
    if (!jsonData) {
        JFErrorLog(@"%@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    if (isDeleEmpty) {
        NSRange range = {0,jsonString.length};
        //去掉字符串中的空格
        [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    }
    
    if (isDeleNewline) {
        NSRange range2 = {0,mutStr.length};
        //去掉字符串中的换行符
        [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    }
    return mutStr;
}


+ (NSDictionary *)extractRtpCapabilities:(NSString *)nativeSdp {
    json json_sdp = sdptransform::parse(nativeSdp.UTF8String);
    auto clientCapabilities = commonUtils_cpp::extractRtpCapabilities(json_sdp);
    NSDictionary *local_cap = [self transportJson:clientCapabilities];
    return local_cap;
}

+ (NSDictionary *)sdpTransportToDictionary:(NSString *)nativeSdp {
    json json_sdp = sdptransform::parse(nativeSdp.UTF8String);
    NSDictionary *localSdp = [self transportJson:json_sdp];
    return localSdp;
}

+ (NSDictionary *)transportJson:(json)jsondata {
    const std::string string_data = jsondata.dump();
    const char *p_data = string_data.data();
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:p_data length:strlen(p_data)] options:NSJSONWritingPrettyPrinted error:nil];
    return dictionary;
}

+ (NSString *)transportToNativeSdp:(NSDictionary *)sdpObj {
    NSString *jsonString = [J_Utils jsonStringWithDict:sdpObj isDeleNewline:NO isDeleEmpty:NO];;
    json json_sdp = json::parse(jsonString.UTF8String);
    std::string temp = sdptransform::write(json_sdp);
    NSString *remoteSdp = [NSString stringWithUTF8String:temp.data()];
    return remoteSdp;
}

@end
