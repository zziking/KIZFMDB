//
//  NSObject+KIZFMDB.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/2.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import "NSObject+KIZFMDB.h"
#import "KIZDBProtocol.h"
#import <objc/runtime.h>
#import "KIZFMDBPrivate.h"

typedef NS_ENUM(NSUInteger, KIZDBOperateType) {
    KIZDBOperateInsert,
    KIZDBOperateReplace,
    KIZDBOperateUpdate,
    KIZDBOperateDelete
};

//see http://www.sqlite.org/datatype3.html

NSString *const KIZSQLiteTypeText    = @"TEXT";//UTF-8、UTF16BE、UTF-16LE编码存储的字符类型， VARCHAR、NVARCHAR、CLOB
NSString *const KIZSQLiteTypeReal    = @"REAL";//浮点类型 REAL、DOUBLE、DOUBLE PRECISION、FLOAT
NSString *const KIZSQLiteTypeInt     = @"INTEGER";//有符号整型 INT、INTEGER、TINYINT、SMALLINT、MEDIUMINT、BIGINT、UNSIGNED BIG INT
NSString *const KIZSQLiteTypeBLOB    = @"NONE";//二进制数据类型
NSString *const KIZSQLiteTypeNumber  = @"NUMBERIC";// NUMERIC、DECIMAL(10,5)、 BOOLEAN、 DATE、DATETIME
NSString *const KIZSQLiteTypeDate    = @"DATETIME";// 实际在Sqlite中为NUMBERIC类型，为了区分NSDate，增加此类型


#pragma clang diagnostic ignored "-Wprotocol"

@implementation NSObject (KIZFMDB)


#pragma mark-
/** 同步保存到数据库 */
- (BOOL)kiz_saveWithError:(NSError **)error{
    
    AssetDBNotNil;
    
    NSArray *values = nil;
    NSString *sql = [self __buildSaveOrReplaceSql:KIZDBOperateInsert arguments:&values];
    
    //执行SQL语句，插入数据
    __block BOOL success = YES;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql withArgumentsInArray:values];
        if (error) {
            *error = success ? nil : db.lastError;
        }
        
    }];
    
    return success;
}
/**
 *  异步保存对象到数据库
 *
 *  @param completion 
 */
- (void)kiz_save:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self kiz_saveWithError:&error];
        DBCompletionBlock(error);
    });
    
}

/** 同步 SaveOrUpdate */
- (BOOL)kiz_saveOrUpdateWithError:(NSError **)error{
    
    AssetDBNotNil;
    
    NSArray *values = nil;
    NSString *sql = [self __buildSaveOrReplaceSql:KIZDBOperateReplace arguments:&values];
    
    //执行SQL语句，插入数据
    __block BOOL success = YES;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql withArgumentsInArray:values];
        if (error) {
            *error = success ? nil : db.lastError;
        }
    }];
    
    return success;
}

/** 异步 SaveOrUpdate */
- (void)kiz_saveOrUpdate:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self kiz_saveOrUpdateWithError:&error];
        DBCompletionBlock(error);
    });
    
}

/** 同步 删除当前记录，根据主键来删除，需要确保主键的值不为空 */
- (BOOL)kiz_removeWithError:(NSError **)error{
    
    AssetDBNotNil;
    
    NSArray *arguments = nil;
    NSError *mError = nil;
    NSString *sql = [self __buildDeleteSqlWithArguments:&arguments error:&mError];
    
    if (mError) {
        if (error) {
            *error = mError;
        }
        return NO;
    }
    
    //执行SQL语句，插入数据
    __block BOOL success = YES;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql withArgumentsInArray:arguments];
        if (error) {
            *error = success ? nil : db.lastError;
        }
    }];
    
    return success;
}

/** 异步 删除当前记录，根据主键来删除，需要确保主键的值不为空 */
- (void)kiz_remove:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self kiz_removeWithError:&error];
        DBCompletionBlock(error);
    });
}

/**
 *  更新对象到数据库
 *  @param properties 要更新的属性
 *  @param error
 *  @return
 */
- (BOOL)kiz_updateWithProperties:(NSArray<NSString *> *)properties error:(NSError **)error{
    
    AssetDBNotNil;
    
    NSDictionary *params = nil;
    
    //构造UPDATE Sql语句
    NSError *mError = nil;
    NSString *sql = [self __buildUpdateSqlWithProperties:properties arguments:&params error:&mError];
    
    if (mError) {
        if (error) {
            *error = mError;
        }
        return NO;
    }
    
    KIZDebug(@"######\nsql-->%@\n#######", sql);
    __block BOOL success = YES;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql withParameterDictionary:params];
        if (error) {
            *error = success ? nil : db.lastError;
        }
    }];
    
    return success;
}

/** 同步 更新 */
- (BOOL)kiz_updateWithError:(NSError **)error{
    
    BOOL success = [self kiz_updateWithProperties:nil error:error];
    
    return success;
}

/** 异步 更新数据 */
- (void)kiz_update:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self kiz_updateWithError:&error];
        DBCompletionBlock(error);
    });
}

/** 同步 批量插入数据 */
+ (BOOL)kiz_batchSave:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error{
    
    AssetDBNotNil;
    
    __block BOOL success = YES;
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSObject *obj in objects) {
            
            NSArray *values = nil;
            NSString *sql = [obj __buildSaveOrReplaceSql:KIZDBOperateInsert arguments:&values];
            
            success = [db executeUpdate:sql withArgumentsInArray:values];
            if (!success) {
                //有一条数据插入失败则回滚
                *rollback = YES;
                if (error) {
                    *error = db.lastError;
                }
                
                return;
            }
        }
        
    }];
    
    return success;
}

/** 批量插入数据 */
+ (void)kiz_batchSave:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self.class kiz_batchSave:objects error:&error];
        DBCompletionBlock(error);
    });
    
}

/** 同步 批量更新 */
+ (BOOL)kiz_batchUpdate:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error{
    
    AssetDBNotNil;
    
    __block BOOL success = YES;
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSObject *obj in objects) {
            
            NSDictionary *params = nil;
            NSError *mError = nil;
            NSString *sql = [obj __buildUpdateSqlWithProperties:nil arguments:&params error:&mError];
            
            if (mError) {
                if (error) {
                    *error = mError;
                }
                *rollback = YES;//回滚
                return;
            }
            
            success = [db executeUpdate:sql withParameterDictionary:params];
            if (!success) {
                //有一条数据插入失败则回滚
                *rollback = YES;
                if (error) {
                    *error = db.lastError;
                }
                
                return;
            }
        }
        
    }];
    
    return success;
}

/** 异步 批量更新 */
+ (void)kiz_batchUpdate:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self.class kiz_batchUpdate:objects error:&error];
        DBCompletionBlock(error);
    });
    
}

/**
 *  同步 批量SaveOrUpdate
 *  @param objects
 *  @param error
 *  @return
 */
+ (BOOL)kiz_batchSaveOrUpdate:(NSArray<id<KIZDBProtocol>> *)objects error:(NSError **)error{
    
    AssetDBNotNil;
    
    __block BOOL success = YES;
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSObject *obj in objects) {
            
            NSArray *values = nil;
            NSString *sql   = [obj __buildSaveOrReplaceSql:KIZDBOperateReplace arguments:&values];
            
            BOOL success = [db executeUpdate:sql withArgumentsInArray:values];
            if (!success) {
                //有一条数据插入失败则回滚
                *rollback = YES;
                success = NO;
                if (error) {
                    *error = db.lastError;
                }
                return;
            }
        }
        
    }];
    
    return success;
}

/**
 *  异步 批量SaveOrUpdate
 *  @param objects
 *  @param completion
 */
+ (void)kiz_batchSaveOrUpdate:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion{
    
    AssetDBNotNil;
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self.class kiz_batchSaveOrUpdate:objects error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    });

}

/** 批量删除 */
+ (void)kiz_batchRemove:(NSArray<id<KIZDBProtocol>> *)objects completion:(KIZDBOperateCompletion)completion{
    
    AssetDBNotNil;
    
    if (objects.count == 0) {
        return;
    }
    
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSObject *obj in objects) {
            NSArray *arguments = nil;
            NSError *error     = nil;
            NSString *sql      = [obj __buildDeleteSqlWithArguments:&arguments error:&error];
            
            if (error) {
                *rollback = YES;//回滚
                DBCompletionBlock(error);
                return;
            }
            
            BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
            if (!success) {
                //有一条数据插入失败则回滚
                *rollback = YES;
                
                DBCompletionBlock(db.lastError);
                
                return;
            }
        }
        
        DBCompletionBlock(nil);
        
    }];
    
}

/** 删除所有记录 */
+ (void)kiz_removeAll:(KIZDBOperateCompletion)completion{
    
    AssetDBNotNil;
    
    [self.class kiz_removeWhere:nil arguments:nil completion:completion];
    
}

/** 按条件删除 */
+ (void)kiz_removeWhere:(NSString *)where arguments:(NSArray *)arguments completion:(KIZDBOperateCompletion)completion{
    
    AssetDBNotNil;
    
    if (where.length > 0) {
        where = [@"WHERE " stringByAppendingString:where];
    }else{
        where = @"";
    }
    
    NSString *tableName   = [self.class kiz_tableName];
    NSMutableString *sql  = [[NSMutableString alloc] initWithFormat:@"DELETE FROM %@ %@", tableName, where];
    
    KIZDebug(@"######\nsql-->%@\n#######", sql);
    
    __block NSError *error= nil;
    [KIZFMDBQueue inDatabase:^(FMDatabase *db) {
        BOOL success = [db executeUpdate:sql withArgumentsInArray:arguments];
        error = success ? nil : db.lastError;
    }];
    DBCompletionBlock(error);
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

#pragma mark- Private Methods
/**
 *  获取Class的类属性数据
 *
 *  @return <propertyName : KIZDBClassProperty>
 */
+ (NSDictionary<NSString *, KIZDBClassProperty *> *)kiz_getDBClassProperties{
    NSDictionary *dic = objc_getAssociatedObject(self.class, @selector(kiz_getDBClassProperties));
    
    if (!dic) {
        dic = [self kiz_initDBClassProperties];
        //缓存属性到类中
        objc_setAssociatedObject(self.class,
                                 @selector(kiz_getDBClassProperties),
                                 dic,
                                 OBJC_ASSOCIATION_RETAIN    //atomic
                                 );
    }
    
    return dic;
}

/**
 *  初始化Class的类属性数据
 *
 *  @return
 */
+ (NSMutableDictionary<NSString *, KIZDBClassProperty *> *)kiz_initDBClassProperties{
    
    NSMutableDictionary<NSString *, KIZDBClassProperty *> *propertyDic = [NSMutableDictionary dictionary];
    
    Class class = [self class];
    
    NSArray<NSString *> *ignoreProperties = [class kiz_tableIgnoreProperties];
    
    //遍历继承关系中的属性
    Class targetClass = class;
    Class topestClass = [class kiz_tableColumnTrackToParentClass];
    
    while (targetClass && targetClass != [NSObject class]) {
        
        unsigned int propertyCount;
        objc_property_t *propertyList = class_copyPropertyList(targetClass, &propertyCount);
        
        //遍历class的property
        for (int i=0; i<propertyCount; i++) {
            
            KIZDBClassProperty *classProperty = [[KIZDBClassProperty alloc] init];
            
            //获得property名称
            objc_property_t property = propertyList[i];
            NSString *propertyName   = [NSString stringWithUTF8String:property_getName(property)];
            
            //忽略属性
            if ([ignoreProperties containsObject:propertyName]) {
                continue;
            }
            
            const char *attrs = property_getAttributes(property);
            NSString *propertyAttributes = @(attrs);
            NSArray *attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            //忽略read-only 属性
            if ([attributeItems containsObject:@"R"]) {
                continue;
            }
            
            //property对应的SQLite类型
            NSString *sqlType = [self sqliteColumnTypeFromObjc_property_t:property];
            if (!sqlType) {
                //NSArray、NSDictionary等类型不支持
                continue;
            }
            
            classProperty.name          = propertyName;
            classProperty.dbColumnType  = sqlType;
            classProperty.dbColumnName  = [class kiz_tableColumnPropertyMap][propertyName] ?: propertyName;
            classProperty.defaultValue  = [class kiz_propertyDefaultValues][propertyName];
            classProperty.isNonNull     = [[class kiz_nonNullProperties] containsObject:propertyName];
            classProperty.isUnique      = [[class kiz_uniqueProperties] containsObject:propertyName];
            classProperty.isPrimarykey  = [[class kiz_primaryKeys] containsObject:propertyName];
            

            NSScanner *scanner = [NSScanner scannerWithString:propertyAttributes];
            [scanner scanUpToString:@"T" intoString: nil];
            [scanner scanString:@"T" intoString:nil];
            
            NSString *propertyType;
            //property的类型是class
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {
                
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];
                
                classProperty.classType = NSClassFromString(propertyType);
                classProperty.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                
            }
            
            //添加到字典中
            [propertyDic setValue:classProperty forKey:propertyName];
            
        }
        
        if (!topestClass || targetClass == topestClass) {
            break;
            
        }else{
            targetClass = class_getSuperclass(targetClass);
        }
        
        free(propertyList);
    }

    return propertyDic;
}

/**
 *  构造 INSERT或者 REPLACE(save or update) 语句
 *
 *  @param insertOrReplace [INSERT, REPLACE]之一的字符串
 *  @param completion
 */
- (NSString *)__buildSaveOrReplaceSql:(KIZDBOperateType)operateType arguments:(NSArray **)args{
    
    AssetDBNotNil;
    
    NSString *insertOrReplace = nil;
    if (operateType == KIZDBOperateInsert) {
        insertOrReplace = @"INSERT";
    }else if (operateType == KIZDBOperateReplace){
        insertOrReplace = @"REPLACE";
    }else{
        return nil;
    }
    
    Class class = self.class;
    
    NSString *tableName = [class kiz_tableName];
    
    NSMutableString *sql = [[NSMutableString alloc] initWithFormat:@"%@ INTO %@(", insertOrReplace, tableName];
    NSMutableString *arguments = [[NSMutableString alloc] initWithFormat:@" VALUES("];
    NSMutableArray *values = [NSMutableArray array];
    
    //构造INSERT SQL语句
    NSDictionary<NSString *, KIZDBClassProperty *> *classPropertyDic = [class kiz_getDBClassProperties];
    [classPropertyDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
        
        id v = [self valueForKeyPath:classProperty.name];

        //插入数据时，为空的字段不插入
        if (operateType == KIZDBOperateReplace || (operateType == KIZDBOperateInsert && v != nil) ) {
            
            [sql appendFormat:@" %@,", classProperty.dbColumnName];
            [arguments appendString:@" ?,"];
            
            v = v ?: [NSNull null];
            [values addObject:v];
        }
        
    }];
    
    [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
    [arguments deleteCharactersInRange:NSMakeRange(arguments.length - 1, 1)];
    [arguments appendString:@")"];
    [sql appendFormat:@") %@", arguments];
    
    KIZDebug(@"#########\nSQL:%@ \n#########\n", sql);
    
    *args = [values copy];
    return sql;
}


/**
 *  构造UPDATE Sql语句
 *  @param properties 要update的字段
 *  @param arguments  存放参数的dic
 *  @param error      错误信息
 *
 *  @return
 */
- (NSString *)__buildUpdateSqlWithProperties:(NSArray<NSString *> *)properties arguments:(NSDictionary **)arguments error:(NSError **)error{
    
    NSString *tableName    = [self.class kiz_tableName];
    
    NSMutableString *sql   = [[NSMutableString alloc] initWithFormat:@"UPDATE %@ SET ", tableName];
    NSMutableString *where = [[NSMutableString alloc] initWithString:@" WHERE 1=1 "];
    NSArray *primaryKeys   = [self.class kiz_primaryKeys];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    NSDictionary<NSString *, KIZDBClassProperty *> *classProperties = [self.class kiz_getDBClassProperties];
    
    [classProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
        
        id value = [self valueForKey:propertyName];
        NSString *columnName = classProperty.dbColumnName;
        
        if (![primaryKeys containsObject:propertyName]) {
            //如果指定了更新的字段，则只更新这些字段
            if (properties.count == 0 || [properties containsObject:propertyName]) {
                [sql appendFormat:@" %@=:%@,", columnName, columnName];
                [params setValue:value ?: [NSNull null] forKey:columnName];
            }
            
        }else{
            
            if (value) {
                //where子句
                [where appendFormat:@" AND %@=:%@", columnName, columnName];
                [params setValue:value forKey:columnName];
                
            }else{
                //主键的值为空
                *stop  = YES;
                
                *error = [NSError errorWithDomain:@"com.kingizz.kizfmdb"
                                             code:-100
                                         userInfo:@{
                                                    NSLocalizedDescriptionKey : [NSString stringWithFormat:@"the primary key %@'s value is invalid:%@", propertyName, value]
                                                   }
                         ];
                
            }
            
        }
        
    }];
    
    [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
    [sql appendString:where];
    
    if (*error) {
        return nil;
    }
    
    *arguments = params;
    
    KIZDebug(@"#########\nSQL:%@ \n#########\n", sql);
    
    return sql;
}

/**
 *  构造DELETE语句
 *
 *  @param arguments
 *  @param error
 *
 *  @return
 */
- (NSString *)__buildDeleteSqlWithArguments:(NSArray **)arguments error:(NSError **)error{
    NSMutableString *where = [[NSMutableString alloc] initWithString:@" WHERE 1=1"];
    NSArray<NSString *> *primaryKeys    = [self.class kiz_primaryKeys];
    NSMutableArray *params   = [[NSMutableArray alloc] initWithCapacity:primaryKeys.count];
    
    NSDictionary<NSString *, KIZDBClassProperty *> *classProperties = [self.class kiz_getDBClassProperties];
    
    for (NSString *key in primaryKeys) {
        id value = [self valueForKey:key];
        if (!value) {
            *error = [NSError errorWithDomain:@"com.kingizz.kizfmdb"
                                         code:-100
                                     userInfo:@{
                                                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"the primary key %@'s value is invalid:%@", key, value]
                                                }
                      ];
            return nil;
        }
        
        [where appendFormat:@" AND %@=?", classProperties[key].dbColumnName];
        [params addObject:value];
    }
    
    if (*error) {
        return nil;
    }
    
    NSString *tableName   = [self.class kiz_tableName];
    NSMutableString *sql  = [[NSMutableString alloc] initWithFormat:@"DELETE FROM %@ %@", tableName, where];
    
    KIZDebug(@"######\nsql-->%@\n#######", sql);
    
    *arguments = [params copy];
    
    return sql;
}

/**
 将对象属性的类型映射到Sqlite数据库类型
 */
+ (NSString *)sqliteColumnTypeFromObjc_property_t:(objc_property_t)property
{
    char *type = property_copyAttributeValue(property, "T");
    NSString *sqliteType = nil;
    switch (type[0]) {
        case 'f':   // float
        case 'd':   // double
            sqliteType = KIZSQLiteTypeReal;
            break;
        case 'c':   // char、BOOL
        case 'C':   // unsigned char、Boolean
        case 's':   // short
        case 'S':   // unsigned short
        case 'i':   // int
        case 'I':   // unsigned int
        case 'l':   // long
        case 'L':   // unsigned long
        case 'q':   // longl long、 NSInteger
        case 'Q':   // usigned long long、 NSUInteger
            sqliteType = KIZSQLiteTypeInt;
            break;
        case 'B':   // bool
            sqliteType = KIZSQLiteTypeNumber;
            break;
        case '@':
        {
            NSString *clsStr = [NSString stringWithUTF8String:type];
            clsStr = [clsStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            clsStr = [clsStr stringByReplacingOccurrencesOfString:@"@" withString:@""];
            clsStr = [clsStr stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            
            Class cls = NSClassFromString(clsStr);
            
            if ([cls isSubclassOfClass:NSString.class] || [cls isSubclassOfClass:NSMutableString.class]) {
                sqliteType = KIZSQLiteTypeText;
            }
            
            else if ([cls isSubclassOfClass:NSNumber.class]) {
                sqliteType = KIZSQLiteTypeNumber;
            }
            
            else if ([cls isSubclassOfClass:NSDate.class]) {
                sqliteType = KIZSQLiteTypeDate;
            }
            
            else if ([cls isSubclassOfClass:NSData.class]) {
                sqliteType = KIZSQLiteTypeBLOB;
            }
            
            //其他类型不支持
            
            break;
        }
        default:{
            //默认为字符串类型
            sqliteType = KIZSQLiteTypeText;
        }
    }
    
    free(type);
    
    return sqliteType;
}

//static Class getClassByProperty(objc_property_t property){
//    char *type = property_copyAttributeValue(property, "T");
//    if (type[0] == '@') {
//        NSString *clsStr = [NSString stringWithUTF8String:type];
//        clsStr = [clsStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        clsStr = [clsStr stringByReplacingOccurrencesOfString:@"@" withString:@""];
//        clsStr = [clsStr stringByReplacingOccurrencesOfString:@"\"" withString:@""];
//        
//        Class cls = NSClassFromString(clsStr);
//        return cls;
//    }
//    return nil;
//}

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
            NSString *declType   = obj.dbColumnType;
            
            int columnIndex = [rs columnIndexForName:columnName];
            id  columnValue;
            
            if ([declType isEqualToString:KIZSQLiteTypeText]) {
                columnValue = [rs stringForColumnIndex:columnIndex];
                
            }else if ([declType isEqualToString:KIZSQLiteTypeInt]){
                columnValue = [NSNumber numberWithInt:[rs intForColumnIndex:columnIndex]];
                
            }else if ([declType isEqualToString:KIZSQLiteTypeReal]){
                columnValue = [NSNumber numberWithDouble:[rs doubleForColumnIndex:columnIndex]];
                
            }else if ([declType isEqualToString:KIZSQLiteTypeBLOB]){
                columnValue = [rs dataForColumnIndex:columnIndex];
                
            }else if ([declType isEqualToString:KIZSQLiteTypeDate]){
                columnValue = [rs dateForColumnIndex:columnIndex];
                
            }else if ([declType isEqualToString:KIZSQLiteTypeNumber]){
                columnValue = [NSNumber numberWithDouble:[rs doubleForColumnIndex:columnIndex]];
                
            }else{
                columnValue = [rs stringForColumnIndex:columnIndex];
            }
            
            [instance setValue:columnValue forKeyPath:propertyName];
            
        }];
        
        [results addObject:instance];
        
    }
    
    [rs close];
    return results;
}

@end
