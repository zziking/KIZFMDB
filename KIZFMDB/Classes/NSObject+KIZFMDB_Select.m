//
//  NSObject+KIZFMDB_Select.m
//  KIZFMDB
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "NSObject+KIZFMDB_Select.h"
#include "NSObject+KIZFMDB.h"
#import "KIZFMDBPrivate.h"

@interface NSObject (Private)

+ (NSDictionary<NSString *, KIZDBClassProperty *> *)kiz_getDBClassProperties;

@end

@implementation NSObject (KIZFMDB_Select)

+ (NSNumber *)numberValueOfQuery:(NSString *)query arguements:(NSArray *)arguments{
    return nil;
}

+ (NSString *)stringValueOfQuery:(NSString *)query arguements:(NSArray *)arguments{
    return nil;
}

+ (NSData *)dataValueOfQuery:(NSString *)query arguements:(NSArray *)arguments{
    return nil;
}

+ (NSDate *)dateValueofQuery:(NSString *)query arguements:(NSArray *)arguments{
    return nil;
}

/**
 *  同步SELECT
 *  @param where
 *  @param arguments
 *  @return nil if error
 */
+ (NSArray *)kiz_selectWhere:(NSString *)where arguments:(NSArray *)arguments error:(NSError **)error{
    
    AssetDBNotNil;
    
    NSString *tableName = [self.class kiz_tableName];
    
    if (where.length > 0) {
        where = [@"WHERE " stringByAppendingString:where];
    }else{
        where = @"";
    }
    
    NSMutableString *sql = [[NSMutableString alloc] initWithFormat:@"SELECT * FROM %@ %@", tableName, where];
    
    KIZDebug(@"#SQL-->%@", sql);
    
    __block NSArray *results = nil;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:arguments];
        results = [self.class parseResultSet:rs];
        if (error) {
            *error = rs ? nil : db.lastError;
        }
        
        [rs close];
        
    }];
    
    return results;
}


/** 异步SELECT */
+ (void)kiz_selectWhere:(NSString *)where arguments:(NSArray *)arguments completion:(void(^)(NSArray *results, NSError *error))completion{
    
    AssetDBNotNil;
    
    if (!completion) {
        return;
    }
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        NSArray *results = [self.class kiz_selectWhere:where arguments:arguments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(results, error);
        });
    });
    
}


+ (NSArray<NSDictionary *> *)kiz_select:(NSString *)select where:(NSString *)where arguments:(NSArray *)arguments error:(NSError **)error{
    
    AssetDBNotNil;
    
    NSString *tableName = [self.class kiz_tableName];
    
    if (where.length > 0) {
        where = [@"WHERE " stringByAppendingString:where];
    }else{
        where = @"";
    }
    
    NSMutableString *sql = [[NSMutableString alloc] initWithFormat:@"SELECT %@ FROM %@ %@", select, tableName, where];
    
    KIZDebug(@"#SQL-->%@", sql);
    
    __block NSMutableArray *resultArray = nil;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet *resultSet = [db executeQuery:sql withArgumentsInArray:arguments];
        if (error && !resultSet) {
            *error = db.lastError;
        }else{
            resultArray = [NSMutableArray array];
            while (resultSet.next) {
                NSDictionary *dic = [resultSet resultDictionary];
                [resultArray addObject:dic];
            }
        }
        
        [resultSet close];
    }];
    
    return resultArray;
}

+ (void)kiz_select:(NSString *)select where:(NSString *)where arguments:(NSArray *)arguments completion:(void(^)(NSArray<NSDictionary *>  *resultArray, NSError *error))completion{
    
    if (!completion) {
        return;
    }
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        NSArray<NSDictionary *>  *resultArray = [self.class kiz_select:select where:where arguments:arguments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(resultArray, error);
        });
        
    });
    
}

#pragma mark-

/**
 将ResutlSet转换成aclass指定的对象
 */
+ (NSMutableArray *)parseResultSet:(FMResultSet *)rs{
    
    if (!rs) {
        return nil;
    }
    
    Class aclass = self.class;
    NSMutableArray *results = [[NSMutableArray alloc] init];
    
    NSDictionary<NSString *, KIZDBClassProperty *> *classProperties = [aclass kiz_getDBClassProperties];
    
    while ([rs next]) {
        
        id instance = [[aclass alloc] init];
        
        [classProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, KIZDBClassProperty * _Nonnull obj, BOOL * _Nonnull stop) {
            
            NSString *columnName = obj.dbColumnName;
            
            int columnIndex = [rs columnIndexForName:columnName];
            id  columnValue;
            
            switch (obj.propertyType) {
                case KIZPropertyTypeString: {
                    columnValue = [rs stringForColumnIndex:columnIndex];
                    break;
                }
                case KIZPropertyTypeInteger: {
                    columnValue = [NSNumber numberWithLongLong:[rs longLongIntForColumnIndex:columnIndex]];
                    break;
                }
                case KIZPropertyTypeFloat: {
                    columnValue = [NSNumber numberWithDouble:[rs doubleForColumnIndex:columnIndex]];
                    break;
                }
                case KIZPropertyTypeBlob: {
                    columnValue = [rs dataForColumnIndex:columnIndex];
                    break;
                }
                case KIZPropertyTypeDate: {
                    columnValue = [rs dateForColumnIndex:columnIndex];
                    break;
                }
                    
            }
            
            
            
            [instance setValue:columnValue forKeyPath:propertyName];
            
        }];
        
        [results addObject:instance];
        
    }
    
    [rs close];
    return results;
}

@end
