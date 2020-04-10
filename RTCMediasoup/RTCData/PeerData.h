//
//  PeerData.h
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/22.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ConsumerData;

@interface PeerData : NSObject

@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) NSString *displayName;

@property (nonatomic, strong) NSArray <ConsumerData *>*consumers;

@property (nonatomic, strong) NSArray <ConsumerData *>*audioConsumers;

@property (nonatomic, strong) NSArray <ConsumerData *>*videoConsumers;

- (instancetype)init:(NSString *)name displayName:(NSString *)displayName;


- (NSDictionary *)dictonary;

@end

NS_ASSUME_NONNULL_END
