//
//  KIZDBHelper.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import "KIZDBManager.h"
#import "KIZDBClassProperty.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "KIZDatabaseQueue.h"

static NSString *const KIZFMDBQueue = @"com.kingizz.KIZFMDBQueue";

@interface KIZDBManager()

@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation KIZDBManager{
    int _currentDBVersion; //database version
}

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
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
        _queue = dispatch_queue_create([KIZFMDBQueue UTF8String], attr);
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
    
    _fmdbQueue = [[self databaseQueueClass] databaseQueueWithPath:path];

    _currentDBVersion = self.dbVersion;
}

- (Class)databaseQueueClass{
    return [KIZDatabaseQueue class];
}

/** 更改数据库路径 */
- (void)changeDataBasePath:(NSString *)filePath{
    
    @synchronized(self.fmdbQueue) {
        
        if ([self.fmdbQueue.path isEqualToString:filePath]) {
            return;
        }
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        // 创建数据库目录
        NSRange lastComponent = [filePath rangeOfString:@"/" options:NSBackwardsSearch];
        
        if (lastComponent.length > 0) {
            NSString* dirPath = [filePath substringToIndex:lastComponent.location];
            BOOL isDir = NO;
            BOOL isCreated = [fileManager fileExistsAtPath:dirPath isDirectory:&isDir];
            
            if ((isCreated == NO) || (isDir == NO)) {
                NSError* error = nil;
                
                BOOL success = [fileManager createDirectoryAtPath:dirPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
                
                if (success == NO) {
                    NSLog(@"create dir error: %@", error.debugDescription);
                }
                
                self.fmdbQueue = [[self databaseQueueClass] databaseQueueWithPath:filePath];
                
            }else{
                self.fmdbQueue = [[self databaseQueueClass] databaseQueueWithPath:filePath];
                _currentDBVersion = self.dbVersion;
            }
            
        }
        
        
        //切换了数据库路径时，也要判断是否要升级数据库
        if (self.fmdbQueue && _currentDBVersion != self.dbVersion) {
            [self setDbVersion:_currentDBVersion];
        }
        
    }
    
}

- (int)dbVersion{
    __block int version = 0;
    [self.fmdbQueue inDatabase:^(FMDatabase *db) {
        version = db.userVersion;
    }];

    return version;
}

- (void)setDbVersion:(int)version{
    
    int dbVersion = self.dbVersion;
    
    if (dbVersion == version) {
        return;
    }
    
    if (self.upgradeBlock) {
        self.upgradeBlock(self.fmdbQueue, dbVersion, version);
    }else if ([self.delegate respondsToSelector:@selector(dataBaseQueue:upgradeFromVersion:toVersion:)]){
        [self.delegate dataBaseQueue:self.fmdbQueue upgradeFromVersion:dbVersion toVersion:version];
    }
    
    [self.fmdbQueue inDatabase:^(FMDatabase *db) {
        [db setUserVersion:version];
    }];
    
    _currentDBVersion = version;
}

@end
