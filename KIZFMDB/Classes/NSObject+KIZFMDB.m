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

#pragma clang diagnostic ignored "-Wprotocol"

@implementation NSObject (KIZFMDB)


#pragma mark-
/** 同步保存到数据库 */
- (BOOL)kiz_saveWithError:(NSError **)error{
    
    return  [self __executeInsertOrReplace:KIZDBOperateInsert error:error];
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
- (BOOL)kiz_replaceWithError:(NSError **)error{
    
    return [self __executeInsertOrReplace:KIZDBOperateReplace error:error];
}

/** 异步 SaveOrUpdate */
- (void)kiz_replace:(KIZDBOperateCompletion)completion{
    
    dispatch_async(db_serial_queue, ^{
        NSError *error = nil;
        [self kiz_replaceWithError:&error];
        DBCompletionBlock(error);
    });
    
}

- (BOOL)__executeInsertOrReplace:(KIZDBOperateType)operateType error:(NSError **)error{
    
    AssetDBNotNil;
    
    NSArray *values = nil;
    NSError *mError = nil;
    NSString *sql = [self __buildSaveOrReplaceSql:operateType arguments:&values error:&mError];
    
    if (mError) {
        if (error) {
            *error = mError;
        }
        return NO;
    }
    
    //执行SQL语句，插入数据
    __block BOOL success = YES;
    
    [KIZFMDBQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        success = [db executeUpdate:sql withArgumentsInArray:values];
        
        if (success) {
            
            self.dbRowId = db.lastInsertRowId;
            
            //更新关联对象
            NSDictionary<NSString *, KIZDBClassProperty *> *relateProperties = [self.class kiz_getDBRelateProperties];
            [relateProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
                id relateObj = [self valueForKey:propertyName];
                if (relateObj) {
                    
                    NSArray *pks = [[relateObj class] kiz_primaryKeys];
                    for (NSString *pk in pks) {
                        id v = [relateObj valueForKey:pk];
                        if (v == nil || [v integerValue] == 0) {
                            NSString *forieignKey = [self.class kiz_forieignKeyForProperty:propertyName];
                            if (forieignKey) {
                                v = [self valueForKey:forieignKey];
                                [relateObj setValue:v forKey:pk];
                            }
                        }
                    }
                    
                    
                    success = [relateObj __executeInsertOrReplace:operateType error:error];
                    if (!success) {
                        *stop = YES;
                    }
                }
            }];
        }
        
        if (error) {
            *error = success ? nil : db.lastError;
        }
        
        *rollback = !success;
    }];
    
    return success;
}

#pragma mark-

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
            NSError *mError = nil;
            NSString *sql = [obj __buildSaveOrReplaceSql:KIZDBOperateInsert arguments:&values error:&mError];
            if (mError) {
                if (error) {
                    *error = mError;
                }
                *rollback = YES;
                return;
            }
            
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
            
            BOOL success = [obj kiz_replaceWithError:error];
            
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



#pragma mark- Private Methods
/**
 *  获取Class的类属性数据
 *
 *  @return <propertyName : KIZDBClassProperty>
 */
+ (NSDictionary<NSString *, KIZDBClassProperty *> *)kiz_getDBClassProperties{
    NSDictionary *dic = objc_getAssociatedObject(self.class, @selector(kiz_getDBClassProperties));
    
    if (!dic) {
        [self kiz_initDBClassProperties];
        dic = objc_getAssociatedObject(self.class, @selector(kiz_getDBClassProperties));
    }
    
    return dic;
}

/**  */
+ (NSDictionary<NSString *, KIZDBClassProperty *> *)kiz_getDBRelateProperties{
    NSDictionary *dic = objc_getAssociatedObject(self.class, @selector(kiz_getDBRelateProperties));
    
    if (!dic) {
        [self kiz_initDBClassProperties];
        dic = objc_getAssociatedObject(self.class, @selector(kiz_getDBRelateProperties));
    }
    
    return dic;
}

/**
 *  初始化Class的类属性数据
 *
 *  @return <属性名, classProperty>
 */
+ (void)kiz_initDBClassProperties{
    
    NSMutableDictionary<NSString *, KIZDBClassProperty *> *propertyDic          = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, KIZDBClassProperty *> *relatePropertyDic    = [NSMutableDictionary dictionary];//是关联对象，且可以保存到数据库的属性
    
    Class class = [self class];
    
    NSArray<NSString *> *ignoreProperties = [class kiz_tableIgnoreProperties];
    
    //遍历继承关系中的属性
    Class targetClass = class;
    Class topestClass = [class kiz_tableColumnTrackToParentClass];
    
    while (targetClass && targetClass != [NSObject class]) {
        
        unsigned int propertyCount;
        objc_property_t *propertyList = class_copyPropertyList(targetClass, &propertyCount);
        
        //遍历class的property
        for (unsigned int i=0; i<propertyCount; i++) {
            
            KIZDBClassProperty *classProperty = [[KIZDBClassProperty alloc] init];
            
            BOOL isKIZRelateObj = NO; //是否是关联对象
            
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
            
            classProperty.name          = propertyName;
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
                
                //read through the property protocols
                while ([scanner scanString:@"<" intoString:NULL]) {
                    
                    NSString* protocolName = nil;
                    
                    [scanner scanUpToString:@">" intoString: &protocolName];
                    
                    if ([protocolName isEqualToString:@"KIZOneToOne"]) {
                        isKIZRelateObj = YES;
                    }else{
                        if (NSClassFromString(protocolName)) {
                            classProperty.protocolName = protocolName;
                        }
                    }
                    
                    [scanner scanString:@">" intoString:NULL];
                }
                
                Class cls = NSClassFromString(propertyType);
                if (cls) {
                    
                    classProperty.classType = NSClassFromString(propertyType);
                    classProperty.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);

                    if ([cls __isKIZDBModelClass]) {
                        isKIZRelateObj = YES;
                    }
                    
                }else{
                    //声明类型为id
                    
                }
                
                
            }
            //property 的类型是结构体 structure
            else if ([scanner scanString:@"{" intoString: &propertyType]) {
                [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                                    intoString:&propertyType];
                
                classProperty.isStandardType = NO;
                classProperty.structName     = propertyType;
                
                continue; //暂不支持结构体
                
            }
            //property是基本数据类型
            else{
                classProperty.propertyType = propertyTypeFromObjcPropertyT(property);
            }
            
            //添加到字典中
            if (! isKIZRelateObj) {
                [propertyDic setValue:classProperty forKey:propertyName];
            }else{
                [relatePropertyDic setObject:classProperty forKey:propertyName];
            }
            
            
        }
        
        if (!topestClass || targetClass == topestClass) {
            break;
            
        }else{
            targetClass = class_getSuperclass(targetClass);
        }
        
        free(propertyList);
    }

    //缓存属性到类中
    objc_setAssociatedObject(self.class,
                             @selector(kiz_getDBClassProperties),
                             propertyDic,
                             OBJC_ASSOCIATION_RETAIN    //atomic
                             );
    
    //缓存属性到类中
    objc_setAssociatedObject(self.class,
                             @selector(kiz_getDBRelateProperties),
                             relatePropertyDic,
                             OBJC_ASSOCIATION_RETAIN    //atomic
                             );
}

+ (BOOL)__isKIZDBModelClass{
    Class class = self.class;
    BOOL b = NO;
    while ( class != NSObject.class) {
        b = class_conformsToProtocol(class, @protocol(KIZDBProtocol));
        if (b) {
            break;
        }else{
            class = class_getSuperclass(class);
        }
    }
    
    return b;
}

/**
 *  构造 INSERT或者 REPLACE(save or update) 语句
 *
 *  @param insertOrReplace [INSERT, REPLACE]之一的字符串
 *  @param completion
 */
- (NSString *)__buildSaveOrReplaceSql:(KIZDBOperateType)operateType arguments:(NSArray **)args error:(NSError **)error{
    
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
    __block NSError *mError = nil;
    NSDictionary<NSString *, KIZDBClassProperty *> *classPropertyDic = [class kiz_getDBClassProperties];
    [classPropertyDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, KIZDBClassProperty * _Nonnull classProperty, BOOL * _Nonnull stop) {
        
        id v = [self valueForKeyPath:classProperty.name];
        
        if (v == nil) {
            
            if (classProperty.isPrimarykey ) {
                *stop  = YES;
                mError = [[NSError alloc] initWithDomain:KIZDBErrorDomain
                                                    code:-100
                                                userInfo:@{
                                                           NSLocalizedDescriptionKey : [NSString stringWithFormat:@"primarykey %@ can not be nil", classProperty.protocolName]
                                                           }
                          ];
            }
            
            
        }else{
            if (classProperty.isPrimarykey && operateType == KIZDBOperateInsert ) {
                
                if (classProperty.propertyType == KIZPropertyTypeInteger && [v integerValue] <= 0) {
                    //integer primary key default is auto increment
                    v = nil;
                }
            }

        }
        
        
        if (v !=nil ) {
            [sql appendFormat:@" %@,", classProperty.dbColumnName];
            [arguments appendString:@" ?,"];
            
            [values addObject:v];
        }
        
    }];
    
    if (mError && error) {
        *error = mError;
        return nil;
    }
    
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
static KIZPropertyType propertyTypeFromObjcPropertyT(objc_property_t property)
{
    char *type = property_copyAttributeValue(property, "T");
    switch (type[0]) {
        case 'f':   // float
        case 'd':   // double
            return KIZPropertyTypeFloat;

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
        case 'B':
            return KIZPropertyTypeInteger;
            
        case '@':
        {
//            NSString *clsStr = [NSString stringWithUTF8String:type];
//            clsStr = [clsStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//            clsStr = [clsStr stringByReplacingOccurrencesOfString:@"@" withString:@""];
//            clsStr = [clsStr stringByReplacingOccurrencesOfString:@"\"" withString:@""];
//            
//            Class cls = NSClassFromString(clsStr);
//            
//            //其他类型不支持
            
            break;
        }
        
    }
    
    free(type);
    
    return KIZPropertyTypeString;
}

- (NSInteger)dbRowId{
    return [objc_getAssociatedObject(self, @selector(dbRowId)) integerValue];
}
- (void)setDbRowId:(NSInteger)dbRowId{
    objc_setAssociatedObject(self, @selector(dbRowId), @(dbRowId), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
