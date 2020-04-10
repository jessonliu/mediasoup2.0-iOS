//
//  PeerData.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/22.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "PeerData.h"

@implementation PeerData

- (instancetype)init:(NSString *)name displayName:(NSString *)displayName {
    self = [super init];
    if (self) {
        self.name = name;
        self.displayName = displayName;
    }
    return self;
}

+ (NSArray *)mj_ignoredPropertyNames {
    return @[@"consumers", @"audioConsumers", @"videoConsumers"];
}

- (NSDictionary *)dictonary {
    return [self mj_keyValues];
}

@end
