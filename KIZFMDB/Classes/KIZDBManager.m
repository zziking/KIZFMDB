//
//  KIZDBHelper.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import "KIZDBManager.h"
#import "KIZDBClassProperty.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

static NSString *const KIZFMDBQueue = @"com.kingizz.KIZFMDBQueue";

@interface KIZDBManager()

@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation KIZDBManager

+ (instancetype)sharedInstance{
    static KIZDBManager *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[KIZDBManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create([KIZFMDBQueue UTF8String], DISPATCH_QUEUE_SERIAL);
        [self __initFmdbQueue];
    }
    return self;
}

/** create database file and init the fmdbQueue */
- (void)__initFmdbQueue{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        
        NSError *error = nil;
        [fileManager createDirectoryAtPath:path
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error
         ];
        if (error) {
            return;
        }
        
    }
    
    path = [path stringByAppendingFormat:@"/%@.sqlite", KIZFMDBQueue];
    
    _fmdbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
}

@end
