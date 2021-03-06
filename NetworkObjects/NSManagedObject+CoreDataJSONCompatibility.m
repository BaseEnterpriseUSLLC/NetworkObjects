//
//  NSManagedObject+CoreDataJSONCompatibility.m
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/6/13.
//
//

#import "NSManagedObject+CoreDataJSONCompatibility.h"
#import "NSDate+ISO8601.h"

@implementation NSManagedObject (CoreDataJSONCompatibility)

#pragma mark - Convenience methods

-(NSObject *)JSONCompatibleValueForAttribute:(NSString *)attributeName
{
    NSObject *attributeValue = [self valueForKey:attributeName];
    
    NSObject *jsonValue = [self JSONCompatibleValueForAttributeValue:attributeValue
                                                        forAttribute:attributeName];
    
    return jsonValue;
}

-(void)setJSONCompatibleValue:(NSObject *)value
                 forAttribute:(NSString *)attributeName
{
    NSObject *attributeValue = [self attributeValueForJSONCompatibleValue:value
                                                             forAttribute:attributeName];
    
    [self setValue:attributeValue
            forKey:attributeName];
}


#pragma mark - Conversion Methods

-(NSObject *)JSONCompatibleValueForAttributeValue:(NSObject *)attributeValue
                                     forAttribute:(NSString *)attributeName
{
    return [self.entity JSONCompatibleValueForAttributeValue:attributeValue
                                                forAttribute:attributeName];
}

-(NSObject *)attributeValueForJSONCompatibleValue:(NSObject *)jsonValue
                                     forAttribute:(NSString *)attributeName
{
    
    NSAttributeDescription *attributeDescription = self.entity.attributesByName[attributeName];
    
    if (!attributeDescription) {
        return nil;
    }
    
    Class attributeClass = NSClassFromString(attributeDescription.attributeValueClassName);
    
    // if value is NSNull
    if (jsonValue == [NSNull null]) {
        
        return nil;
    }
    
    // no need to change values
    if (attributeClass == [NSString class] ||
        attributeClass == [NSNumber class]) {
        
        return jsonValue;
    }
    
    // set value based on attribute class...
    
    // date
    if (attributeClass == [NSDate class]) {
        
        // value will be nsstring
        NSString *jsonCompatibleValue = (NSString *)jsonValue;
        
        NSDate *date = [NSDate dateWithISO8601String:jsonCompatibleValue];
        
        return date;
    }
    
    // data
    if (attributeClass == [NSData class]) {
        
        // value will be nsstring
        NSString *jsonCompatibleValue = (NSString *)jsonValue;
        
        NSData *data = [[NSData alloc]initWithBase64EncodedString:jsonCompatibleValue
                                                          options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        return data;
    }
    
    // unknown value
    
    return nil;
}

#pragma mark - Validation

-(BOOL)isValidConvertedValue:(id)convertedValue
                forAttribute:(NSString *)attributeName
{
    NSAttributeDescription *attributeDescription = self.entity.attributesByName[attributeName];
    
    if (!attributeDescription) {
        return NO;
    }
    
    // no JSON conversion for these values, so dont put them in NOResources
    if (attributeDescription.attributeType == NSUndefinedAttributeType ||
        attributeDescription.attributeType == NSTransformableAttributeType ||
        attributeDescription.attributeType == NSObjectIDAttributeType) {
        
        return NO;
    }
    
    // number types
    if (attributeDescription.attributeType == (NSInteger16AttributeType
                                               | NSInteger32AttributeType
                                               | NSInteger64AttributeType
                                               | NSDecimalAttributeType
                                               | NSDoubleAttributeType
                                               | NSFloatAttributeType
                                               | NSBooleanAttributeType)) {
        
        if ([convertedValue isKindOfClass:[NSNumber class]]) {
            
            return YES;
        }
        
        return NO;
    }
    
    // string type
    if (attributeDescription.attributeType == NSStringAttributeType) {
        
        if ([convertedValue isKindOfClass:[NSString class]]) {
            
            return YES;
        }
        
        return NO;
    }
    
    // date type
    if (attributeDescription.attributeType == NSDateAttributeType) {
        
        if ([convertedValue isKindOfClass:[NSDate class]]) {
            
            return YES;
        }
        
        return NO;
    }
    
    // data type
    if (attributeDescription.attributeType == NSBinaryDataAttributeType) {
        
        if ([convertedValue isKindOfClass:[NSData class]]) {
            
            return YES;
        }
        
        return NO;
    }
    
    return NO;
}

@end

@implementation NSEntityDescription (CoreDataJSONCompatibility)

-(NSObject *)JSONCompatibleValueForAttributeValue:(NSObject *)attributeValue
                                     forAttribute:(NSString *)attributeName
{
    NSAttributeDescription *attributeDescription = self.attributesByName[attributeName];
    
    if (!attributeDescription) {
        return nil;
    }
    
    // give value based on attribute type...
    
    Class attributeClass = NSClassFromString(attributeDescription.attributeValueClassName);
    
    // if nsnull then just return NSNull
    if (attributeValue == [NSNull null]) {
        
        return [NSNull null];
    }
    
    // nil attributes can be represented in JSON by NSNull
    if (!attributeValue) {
        
        return [NSNull null];
    }
    
    // strings and numbers are standard json data types
    if (attributeClass == [NSString class] ||
        attributeClass == [NSNumber class]) {
        
        return attributeValue;
    }
    
    // date
    if (attributeClass == [NSDate class]) {
        
        // convert to string
        NSDate *date = (NSDate *)attributeValue;
        return date.ISO8601String;
    }
    
    // data
    if (attributeClass == [NSData class]) {
        
        NSData *data = (NSData *)attributeValue;
        NSString *stringValue = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        return stringValue;
    }
    
    // error
    return nil;
}

@end
