//
//  NSObject+KIZFMDB_Table.m
//  KIZFMDB
//
//  Created by Eugene on 16/1/13.
//  Copyright © 2016年 hunlimao. All rights reserved.
//

#import "NSObject+KIZFMDB_Table.h"
#import "KIZFMDBPrivate.h"

@interface NSObject (Private)

+ (NSDictionary<NSString *, KIZDBClassProperty *> *)kiz_getDBClassProperties;

@end

@implementation NSObject (KIZFMDB_Table)

/** 非空的属性, 建立数据表时添加非空约束  */
+ (NSArray<NSString *> *)kiz_nonNullProperties{
    return nil;
}
/** 值唯一属性，建立数据表时添加唯一约束 */
+ (NSArray<NSString *> *)kiz_uniqueProperties{
    return nil;
}
/** 自增长属性，建立数据表时，列设为自增长 */
+ (NSArray<NSString *> *)kiz_autoIncrementProperties{
    return nil;
}
/** 属性-默认值 */
+ (NSDictionary<NSString *, NSString *> *)kiz_propertyDefaultValues{
    return nil;
}

+ (NSString *)kiz_tableName{
    return NSStringFromClass([self class]);
}


+ (NSArray<NSString *> *)kiz_primaryKeys{
    return nil;
}

+ (NSDictionary *)kiz_tableColumnPropertyMap{
    return nil;
}

+ (NSArray<NSString *> *)kiz_tableIgnoreProperties{
    //从iOS8之后，通过runtime获得class的property会包含这几个属性
    return @[@"hash", @"superclass", @"description", @"debugDescription"];
}

+ (Class)kiz_tableColumnTrackToParentClass{
    return nil;
}

+ (NSArray<NSString *> *)kiz_tableColumns{
    
    NSMutableArray *columns = [NSMutableArray array];
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        [resultSet close];
    }];
    return columns;
}

+ (BOOL)kiz_createTableWithError:(NSError **)error{
    
    AssetDBNotNil;
    
    NSError *mError = nil;
    NSString *sql = [self __buildCreateTableSQLForClass:self.class error:&mError];
    
    if (mError) {
        if (error) {
            *error = mError;
        }
        return NO;
    }
    
    __block BOOL success = YES;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql];
        if (!success) {
            if (error) {
                *error = db.lastError;
            }
        }
    }];
    
    
    //检查Model是否新增了数据表中没有的属性，如果有，则给表添加这些属性
    
    NSArray *tableColomns    = [self.class kiz_tableColumns];//当前数据表中的所有列
    NSMutableArray<NSString *> *notExistColumns = [NSMutableArray array];//Model新增的属性，Table中没有该列
    
    NSDictionary<NSString *, KIZDBClassProperty *> *classPropertyDic = [self.class kiz_getDBClassProperties];
    [classPropertyDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
        if (![tableColomns containsObject:classProperty.dbColumnName]) {
            [notExistColumns addObject:tableColumnFieldWithClassProperty(classProperty)];
        }
    }];
    
    NSString *tableName = [self.class kiz_tableName];
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (NSString *field in notExistColumns) {
            NSString *alterSql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ", tableName,  field];
            
            if (![db executeUpdate:alterSql]) {
                *rollback = YES;
                break;
            }
        }
    }];
    
    return success;
}

/**
 *  如果数据表不存在，则创建数据表，
 *  @param completion
 */
+ (void)kiz_createTableWithCompletion:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self.class kiz_createTableWithError:&error];
        DBCompletionBlock(error);
    });
}


#pragma mark- Private

static NSString* tableColumnFieldWithClassProperty(KIZDBClassProperty *classProperty){
    NSMutableString *str = [NSMutableString new];
    [str appendFormat:@"%@ %@", classProperty.dbColumnName,  classProperty.dbColumnType];
    if (classProperty.isNonNull) {
        [str appendString:@" NON NULL"];
    }
    if (classProperty.isUnique) {
        [str appendString:@" UNIQUE"];
    }
    if (classProperty.defaultValue.length > 0) {
        [str appendFormat:@" DEFAULT %@", classProperty.defaultValue];
    }
    
    return [str copy];
}

+ (NSString *)__buildCreateTableSQLForClass:(Class<KIZDBProtocol>)clazz error:(NSError **)error{
    NSString *tableName = [clazz kiz_tableName];
    
    if ([clazz kiz_primaryKeys].count == 0) {
        *error = [NSError errorWithDomain:KIZDBErrorDomain
                                     code:-10
                                 userInfo:@{
                                            NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Table [%@] must set primary key, you should implement the [%@ kiz_primaryKeys] method", tableName, NSStringFromClass(self.class)]
                                            }
                  ];
        return nil;
    }
    
    NSMutableString *sql = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE IF NOT EXISTS %@(", tableName];
    
    NSDictionary<NSString *, KIZDBClassProperty *> *classPropertyDic = [(Class)clazz kiz_getDBClassProperties];
    [classPropertyDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
        
        [sql appendFormat:@"%@,", tableColumnFieldWithClassProperty(classProperty)];
        
    }];
    
    
    NSArray<NSString *> *primaryKeys = [clazz kiz_primaryKeys];
    if (primaryKeys.count > 0) {
        //设置主键的SQL语句
        [sql appendString:@" PRIMARY KEY("];
    }
    for (NSString *primaryKey in primaryKeys) {
        
        if ([sql rangeOfString:primaryKey].length > 0) {
            [sql appendFormat:@" %@,", primaryKey];
            
        }else if ([sql rangeOfString:classPropertyDic[primaryKey].dbColumnName].length > 0){
            [sql appendFormat:@" %@,", classPropertyDic[primaryKey].dbColumnName];
        }
        else{
            NSString *errorMsg = [NSString stringWithFormat:@"primarykey:%@ 不是类[%@]或其父类的属性",primaryKey, NSStringFromClass(clazz)];
            *error = [NSError errorWithDomain:KIZDBErrorDomain
                                         code:-1
                                     userInfo:@{
                                                NSLocalizedDescriptionKey : errorMsg
                                                }
                      ];
            return nil;
        }
        
    }
    [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
    if (primaryKeys.count > 0) {
        [sql appendString:@")"];
    }
    
    [sql appendString:@");"];
    
    return [sql copy];
}

@end
