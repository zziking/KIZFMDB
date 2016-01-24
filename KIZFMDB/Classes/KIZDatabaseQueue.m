//
//  KIZDatabaseQueue.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 16/1/21.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "KIZDatabaseQueue.h"
#import "FMDatabase.h"

//static NSString *const KIZDatabaseQueue = @"KIZDatabaseQueue";

@interface FMDatabaseQueue (Private)

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block;

@end

@interface KIZDatabaseQueue ()

@property (weak,    nonatomic) FMDatabase *executingDB;
@property (strong,  nonatomic) NSRecursiveLock *rLock;

@end

@implementation KIZDatabaseQueue

- (instancetype)init{
    self = [super init];
    if (self) {
        _rLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)inDatabase:(void (^)(FMDatabase *db))block{
    
    [self.rLock lock];
    
    if (self.executingDB) {
        block(self.executingDB);
        
    }else{
        [super inDatabase:^(FMDatabase *db){
            self.executingDB = db;
            block(db);
            self.executingDB = nil;
        }];
    }
    
    [self.rLock unlock];
    
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block{
    
    [self.rLock lock];
    
    [super inTransaction:^(FMDatabase *db, BOOL *rollback){
        self.executingDB = db;
        block(db, rollback);
        self.executingDB = nil;
    }];
    
    [self.rLock unlock];
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    if (self.executingDB) {
        
        BOOL shouldRollback = NO;

        if (useDeferred) {
            [self.executingDB beginDeferredTransaction];
        }
        else {
            [self.executingDB beginTransaction];
        }
        
        block(self.executingDB, &shouldRollback);
        
        if (shouldRollback) {
            [self.executingDB rollback];
        }
        else {
            [self.executingDB commit];
        }
        
    }else{
        [super beginTransaction:useDeferred withBlock:block];
    }
}

@end
