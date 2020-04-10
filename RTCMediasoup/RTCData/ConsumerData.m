//
//  ConsumerData.m
//  CinLanMedia
//
//  Created by 刘金丰 on 2019/3/22.
//  Copyright © 2019 Liujinfeng. All rights reserved.
//

#import "ConsumerData.h"

@implementation ConsumerData

+ (NSArray *)mj_ignoredPropertyNames {
    return @[@"idStr", @"kind", @"cid", @"track"];
}

#pragma mark - Getter

- (NSInteger)cid {
    return self.dataID;
}

@end
