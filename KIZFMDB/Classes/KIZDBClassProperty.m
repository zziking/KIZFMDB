//
//  KIZDBClassProperty.m
//  HunLiMaoMerchant
//
//  Created by Eugene on 15/12/3.
//  Copyright © 2015年 hunlimao. All rights reserved.
//

#import "KIZDBClassProperty.h"
#import "KIZDBProtocol.h"

//see http://www.sqlite.org/datatype3.html

static NSString *const KIZSQLiteTypeText    = @"TEXT";//UTF-8、UTF16BE、UTF-16LE编码存储的字符类型， VARCHAR、NVARCHAR、CLOB
static NSString *const KIZSQLiteTypeReal    = @"REAL";//浮点类型 REAL、DOUBLE、DOUBLE PRECISION、FLOAT
static NSString *const KIZSQLiteTypeInt     = @"INTEGER";//有符号整型 INT、INTEGER、TINYINT、SMALLINT、MEDIUMINT、BIGINT、UNSIGNED BIG INT
static NSString *const KIZSQLiteTypeBLOB    = @"NONE";//二进制数据类型
static NSString *const KIZSQLiteTypeNumber  = @"NUMBERIC";// NUMERIC、DECIMAL(10,5)、 BOOLEAN、 DATE、DATETIME
//static NSString *const KIZSQLiteTypeDate    = @"DATETIME";// 实际在Sqlite中为NUMBERIC类型，为了区分NSDate，增加此类型


@implementation KIZDBClassProperty

- (void)setPropertyType:(KIZPropertyType)propertyType{
    
    _propertyType = propertyType;
    
    switch (propertyType) {
        case KIZPropertyTypeString: {
            self.dbColumnType = KIZSQLiteTypeText;
            break;
        }
        case KIZPropertyTypeInteger: {
            self.dbColumnType = KIZSQLiteTypeInt;
            break;
        }
        case KIZPropertyTypeFloat: {
            self.dbColumnType = KIZSQLiteTypeReal;
            break;
        }
        case KIZPropertyTypeBlob: {
            self.dbColumnType = KIZSQLiteTypeBLOB;
            break;
        }
        case KIZPropertyTypeDate: {
            self.dbColumnType = KIZSQLiteTypeNumber;
            break;
        }
        case KIZPropertyTypeKIZObj: {
            self.dbColumnType = KIZSQLiteTypeInt;
            break;
        }
    }
}

- (void)setClassType:(Class)cls{
    
    _classType = cls;
    
    if ([cls isSubclassOfClass:NSString.class] || [cls isSubclassOfClass:NSMutableString.class]) {
        self.propertyType = KIZPropertyTypeString;
    }
    
    else if ([cls isSubclassOfClass:NSNumber.class]) {
        self.propertyType = KIZPropertyTypeFloat;
    }
    
    else if ([cls isSubclassOfClass:NSDate.class]) {
        self.propertyType = KIZPropertyTypeDate;
    }
    
    else if ([cls isSubclassOfClass:NSData.class]) {
        self.propertyType = KIZPropertyTypeBlob;
    }
    
    else if ([cls isSubclassOfClass:NSArray.class]){
        //TODO
    }
    
    else if ([cls conformsToProtocol:@protocol(KIZDBProtocol)]){
        //关联了一个实现了KIZDBProtocol协议的对象
        self.propertyType = KIZPropertyTypeKIZObj;
    }
    
    //其他类型数据以String存储
    else{
        self.propertyType = KIZPropertyTypeString;
    }
    
    ;
}

@end
