//
//  User.m
//  KIZFMDB
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "Person.h"
#import "NSObject+KIZFMDB.h"

@implementation Person

+ (NSDictionary<NSString *, NSString *> *)kiz_propertyDefaultValues{
    return @{
             @"updateTime" : @"(strftime('%s', 'now'))"
             };
}

#pragma mark- KIZDBProtocol

+ (NSArray<NSString *> *)kiz_primaryKeys{
    return @[@"userId"];
}

+ (NSString *)kiz_forieignKeyForProperty:(NSString *)property{
    if ([property isEqualToString:@"idCard"]) {
        return @"id";
    }
    return nil;
}

@end
