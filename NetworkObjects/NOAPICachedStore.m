//
//  NOAPICachedStore.m
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 11/16/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

#import "NOAPICachedStore.h"
#import "NSManagedObject+CoreDataJSONCompatibility.h"

@interface NOAPICachedStore (Cache)

-(NSManagedObject<NOResourceKeysProtocol> *)resource:(NSString *)resourceName
                                              withID:(NSUInteger)resourceID;

-(NSManagedObject<NOResourceKeysProtocol> *)setJSONObject:(NSDictionary *)jsonObject
                                              forResource:(NSString *)resourceName
                                                   withID:(NSUInteger)resourceID;

@end

@interface NSEntityDescription (Convert)

-(NSDictionary *)jsonObjectFromCoreDataValues:(NSDictionary *)values;

@end

@implementation NOAPICachedStore

- (id)init
{
    self = [super init];
    if (self) {
        
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        _context.undoManager = nil;
        
    }
    return self;
}

#pragma mark - Requests

-(NSURLSessionDataTask *)getResource:(NSString *)resourceName
        resourceID:(NSUInteger)resourceID
        completion:(void (^)(NSError *, NSManagedObject<NOResourceKeysProtocol> *))completionBlock
{
    return [self.api getResource:resourceName withID:resourceID completion:^(NSError *error, NSDictionary *resourceDict) {
        
        if (error) {
            
            completionBlock(error, nil);
            
            return;
        }
        
        NSManagedObject<NOResourceKeysProtocol> *resource = [self setJSONObject:resourceDict
                                                                    forResource:resourceName
                                                                         withID:resourceID];
        
        completionBlock(nil, resource);
    }];
}

-(NSURLSessionDataTask *)createResource:(NSString *)resourceName
        initialValues:(NSDictionary *)initialValues
           completion:(void (^)(NSError *, NSManagedObject<NOResourceKeysProtocol> *))completionBlock
{
    NSEntityDescription *entity = self.api.model.entitiesByName[resourceName];
    
    assert(entity);
    
    // convert those Core Data values to JSON
    NSDictionary *jsonValues = [entity jsonObjectFromCoreDataValues:initialValues];
    
    return [self.api createResource:resourceName withInitialValues:jsonValues completion:^(NSError *error, NSNumber *resourceID) {
       
        if (error) {
            
            completionBlock(error, nil);
            
            return;
        }
        
        NSManagedObject<NOResourceKeysProtocol> *resource = [self resource:resourceName
                                                                    withID:resourceID.integerValue];
        
        // set values
        for (NSString *key in initialValues) {
            
            id value = initialValues[key];
            
            // Core Data cannot hold NSNull
            
            if (value == [NSNull null]) {
                
                value = nil;
            }
            
            [resource setValue:value
                        forKey:key];
        }
        
        completionBlock(nil, resource);
    }];
}

-(NSURLSessionDataTask *)editResource:(NSManagedObject<NOResourceKeysProtocol> *)resource
            changes:(NSDictionary *)values
         completion:(void (^)(NSError *))completionBlock
{
    // convert those Core Data values to JSON
    NSDictionary *jsonValues = [resource.entity jsonObjectFromCoreDataValues:values];
    
    // get resourceID
    
    Class entityClass = NSClassFromString(resource.entity.managedObjectClassName);
    
    NSString *resourceIDKey = [entityClass resourceIDKey];
    
    NSNumber *resourceID = [resource valueForKey:resourceIDKey];
    
    return [self.api editResource:resource.entity.name withID:resourceID.integerValue changes:jsonValues completion:^(NSError *error) {
       
        if (error) {
            
            completionBlock(error);
            
            return;
        }
        
        // set values
        for (NSString *key in values) {
            
            id value = values[key];
            
            // Core Data cannot hold NSNull
            
            if (value == [NSNull null]) {
                
                value = nil;
            }
            
            [resource setValue:value
                        forKey:key];
        }
        
        completionBlock(nil);
        
    }];
}

-(NSURLSessionDataTask *)deleteResource:(NSManagedObject<NOResourceKeysProtocol> *)resource
           completion:(void (^)(NSError *))completionBlock
{
    // get resourceID
    
    Class entityClass = NSClassFromString(resource.entity.managedObjectClassName);
    
    NSString *resourceIDKey = [entityClass resourceIDKey];
    
    NSNumber *resourceID = [resource valueForKey:resourceIDKey];
    
    return [self.api deleteResource:resource.entity.name withID:resourceID.integerValue completion:^(NSError *error) {
        
        if (error) {
            
            completionBlock(error);
            
            return;
        }
        
        // delete
        [_context performBlock:^{
           
            [_context deleteObject:resource];
            
            completionBlock(nil);
        }];
    }];
}

-(NSURLSessionDataTask *)performFunction:(NSString *)functionName
            onResource:(NSManagedObject<NOResourceKeysProtocol> *)resource
        withJSONObject:(NSDictionary *)jsonObject
            completion:(void (^)(NSError *, NSNumber *, NSDictionary *))completionBlock
{
    // get resourceID
    
    Class entityClass = NSClassFromString(resource.entity.managedObjectClassName);
    
    NSString *resourceIDKey = [entityClass resourceIDKey];
    
    NSNumber *resourceID = [resource valueForKey:resourceIDKey];
    
    return [self.api performFunction:functionName
                          onResource:resource.entity.name
                              withID:resourceID.integerValue
                      withJSONObject:jsonObject
                          completion:completionBlock];
}

@end

@implementation NOAPICachedStore (Cache)

-(NSManagedObject<NOResourceKeysProtocol> *)resource:(NSString *)resourceName
                                              withID:(NSUInteger)resourceID;
{
    // look for resource in cache
    
    __block NSManagedObject<NOResourceKeysProtocol> *resource;
    
    [self.context performBlockAndWait:^{
        
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:resourceName];
        
        // get entity
        NSEntityDescription *entity = self.api.model.entitiesByName[resourceName];
        
        Class entityClass = NSClassFromString(entity.managedObjectClassName);
        
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %d", [entityClass resourceIDKey], resourceID];
        
        NSError *error;
        
        NSArray *results = [self.context executeFetchRequest:fetchRequest
                                                       error:&error];
        
        if (error) {
            
            [NSException raise:@"Error executing NSFetchRequest"
                        format:@"%@", error.localizedDescription];
            
            return;
        }
        
        resource = results.firstObject;
        
        // create new object if none exists
        if (!resource) {
            
            resource = [NSEntityDescription insertNewObjectForEntityForName:resourceName
                                                     inManagedObjectContext:self.context];
            
            // set resource ID
            entityClass = NSClassFromString(resource.entity.managedObjectClassName);
            
            NSString *resourceIDKey = [entityClass resourceIDKey];
            
            [resource setValue:[NSNumber numberWithInteger:resourceID]
                        forKey:resourceIDKey];
            
        }
    }];
    
    return resource;
}

-(NSManagedObject<NOResourceKeysProtocol> *)setJSONObject:(NSDictionary *)resourceDict
                                              forResource:(NSString *)resourceName
                                                   withID:(NSUInteger)resourceID
{
    // update cache...
    
    NSManagedObject<NOResourceKeysProtocol> *resource = [self resource:resourceName
                                                                withID:resourceID];
    
    // set values...
    
    NSEntityDescription *entity = self.api.model.entitiesByName[resourceName];
    
    for (NSString *attributeName in entity.attributesByName) {
        
        for (NSString *key in resourceDict) {
            
            // found matching key (will only run once because dictionaries dont have duplicates)
            if ([key isEqualToString:attributeName]) {
                
                id value = [resourceDict valueForKey:key];
                
                [resource setJSONCompatibleValue:value
                                    forAttribute:attributeName];
                
                break;
            }
        }
    }
    
    for (NSString *relationshipName in entity.relationshipsByName) {
        
        NSRelationshipDescription *relationship = entity.relationshipsByName[relationshipName];
        
        for (NSString *key in resourceDict) {
            
            // found matching key (will only run once because dictionaries dont have duplicates)
            if ([key isEqualToString:relationshipName]) {
                
                // destination entity
                NSEntityDescription *destinationEntity = relationship.destinationEntity;
                
                // to-one relationship
                if (!relationship.isToMany) {
                    
                    // get the resource ID
                    NSNumber *destinationResourceID = [resourceDict valueForKey:relationshipName];
                    
                    NSManagedObject<NOResourceKeysProtocol> *destinationResource = [self resource:destinationEntity.name withID:destinationResourceID.integerValue];
                    
                    [resource setValue:destinationResource
                                forKey:key];
                }
                
                // to-many relationship
                else {
                    
                    // get the resourceIDs
                    NSArray *destinationResourceIDs = [resourceDict valueForKey:relationshipName];
                    
                    NSMutableSet *destinationResources = [[NSMutableSet alloc] init];
                    
                    for (NSNumber *destinationResourceID in destinationResourceIDs) {
                        
                        NSManagedObject *destinationResource = [self resource:destinationEntity.name withID:destinationResourceID.integerValue];
                        
                        [destinationResources addObject:destinationResource];
                    }
                    
                    [resource setValue:destinationResources
                                forKey:key];
                }
                
            }
        }
    }
    
    return resource;
}

@end

@implementation NSEntityDescription (Convert)

-(NSDictionary *)jsonObjectFromCoreDataValues:(NSDictionary *)values
{
    NSMutableDictionary *jsonObject = [[NSMutableDictionary alloc] init];
    
    // convert values...
    
    for (NSString *attributeName in self.attributesByName) {
        
        for (NSString *key in values) {
            
            // found matching key (will only run once because dictionaries dont have duplicates)
            if ([key isEqualToString:attributeName]) {
                
                id value = [values valueForKey:key];
                
                id jsonValue = [self JSONCompatibleValueForAttributeValue:value
                                                             forAttribute:key];
                
                [jsonObject setObject:jsonValue
                               forKey:key];
                
                break;
            }
        }
    }
    
    for (NSString *relationshipName in self.relationshipsByName) {
        
        NSRelationshipDescription *relationship = self.relationshipsByName[relationshipName];
        
        for (NSString *key in values) {
            
            // found matching key (will only run once because dictionaries dont have duplicates)
            if ([key isEqualToString:relationshipName]) {
                
                // destination entity
                NSEntityDescription *destinationEntity = relationship.destinationEntity;
                
                Class entityClass = NSClassFromString(destinationEntity.managedObjectClassName);
                
                NSString *destinationResourceIDKey = [entityClass resourceIDKey];
                
                // to-one relationship
                if (!relationship.isToMany) {
                    
                    // get resource ID of object
                    
                    NSManagedObject<NOResourceKeysProtocol> *destinationResource = [values objectForKey:key];
                    
                    NSNumber *destinationResourceID = [destinationResource valueForKey:destinationResourceIDKey];
                    
                    [jsonObject setObject:destinationResourceID
                                   forKey:key];
                    
                }
                
                // to-many relationship
                else {
                    
                    NSSet *destinationResources = [values valueForKey:relationshipName];
                    
                    NSMutableArray *destinationResourceIDs = [[NSMutableArray alloc] init];
                    
                    for (NSManagedObject *destinationResource in destinationResources) {
                        
                        NSNumber *destinationResourceID = [destinationResource valueForKey:destinationResourceIDKey];
                        
                        [destinationResourceIDs addObject:destinationResourceID];
                    }
                    
                    [jsonObject setObject:destinationResourceIDs
                                   forKey:key];
                    
                }
                
                break;
            }
        }
    }
    
    return jsonObject;
}

@end