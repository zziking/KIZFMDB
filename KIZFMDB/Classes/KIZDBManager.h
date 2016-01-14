//
//  KIZDBHelper.h
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "KIZDBProtocol.h"


@interface KIZDBManager : NSObject

@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (atomic, strong) FMDatabaseQueue *fmdbQueue;

+ (instancetype)sharedInstance;

@end
