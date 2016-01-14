//
//  KIZFMDBPrivate.h
//  KIZFMDB
//
//  Created by Eugene on 16/1/14.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#ifndef KIZFMDBPrivate_h
#define KIZFMDBPrivate_h

#import "KIZDBManager.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "KIZDBClassProperty.h"

#define AssetDBNotNil NSAssert([KIZDBManager sharedInstance].fmdbQueue, @"未指定FMDatabaseQueue")
#define DBCompletionBlock(error)            if (completion) {                                   \
                                                dispatch_async(dispatch_get_main_queue(), ^{    \
                                                    completion(error);                          \
                                                });                                             \
                                            }

#define db_serial_queue     [KIZDBManager sharedInstance].queue
#define KIZFMDBQueue        [KIZDBManager sharedInstance].fmdbQueue

#define KIZDBErrorDomain @"com.kingizz.dberror"

#define KIZDebug(fmt, ...) NSLog(fmt,  ##__VA_ARGS__)


#endif /* KIZFMDBPrivate_h */
