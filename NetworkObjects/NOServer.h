//
//  NOServer.h
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 9/29/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <NetworkObjects/NOServerConstants.h>

@class NOStore, RouteRequest, RouteResponse, NOHTTPServer;

@protocol NOResourceProtocol;
@protocol NOSessionProtocol;

/**
 This is the server class that broadcasts the Core Data entities in a NOStore (called Resources) over the network.
 */

@interface NOServer : NSObject

/**
 The supported initializer for this class. Do not use -init as it will raise an exception. All parameters must not non-nil.
 
 @param store The NOStore this server will broadcast. Note that only subclasses of NSManagedObject that conform to NOResourceProtocol will be broadcasted.
 
 @param userEntityName The name of the entity that will represent users. It must conform to NOUserProtocol.
 
 @param sessionEntityName The name of the entity that will represent authentication sessions. It must conform to NOSessionProtocol.

 @param clientEntityName The name of the entity that will represents clients that can connect to the server. It must conform to NOClientProtocol.

 @param loginPath This string will be the URL that will be used to authenticate. It must not conflict with any of the resourcePath values that the Resources return.
 
 @return A fully initialized NOServer instance.
 
 @see NOStore

 */

-(id)initWithStore:(NOStore *)store
    userEntityName:(NSString *)userEntityName
 sessionEntityName:(NSString *)sessionEntityName
  clientEntityName:(NSString *)clientEntityName
         loginPath:(NSString *)loginPath;

/**
 The NOStore that NOServer will broadcast.
 
 @see NOStore
 */

@property (readonly) NOStore *store;

/**
 The underlying HTTP server that accepts incoming connections.
 
 @see CocoaHTTPServer
 
 */

@property (readonly) NOHTTPServer *httpServer;

/**
 The name of the entity in NOStore's Managed Object Model that conforms to NOSessionProtocol. There should only be only entity that conforms to NOSessionProtocol in the NOStore's Managed Object Model.
 */

@property (readonly) NSString *sessionEntityName;

/**
 The name of the entity in NOStore's Managed Object Model that conforms to NOUserProtocol. There should only be only entity that conforms to NOUserProtocol in the NOStore's Managed Object Model.
 */

@property (readonly) NSString *userEntityName;

/**
 The name of the entity in NOStore's Managed Object Model that conforms to NOClientProtocol. There should only be only entity that conforms to NOClientProtocol in the NOStore's Managed Object Model.
 */

@property (readonly) NSString *clientEntityName;

/**
 This will be the URL that clients will use to authenticate. This string must be different from the values that NOStore's Resources return in +(NSString *)resourcePath.
 */

@property (readonly) NSString *loginPath;

/**
 This dictionary is lazily initialized and maps NSEntityDescriptions to resourcePaths for REST URL generation.
 
 @see NOResourceProtocol
 */

@property (readonly) NSDictionary *resourcePaths;

/**
 This setting defines whether the JSON output generated should be pretty printed (contain whitespacing for human readablility) or not.
 
 @see NSJSONWritingPrettyPrinted
 
 */

@property BOOL prettyPrintJSON;

/**
 * To enable HTTPS for all incoming connections set this value to an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
 **/

@property NSArray *sslIdentityAndCertificates;

/**
 This setting defines whether the JSON output generated should be pretty printed (contain whitespacing for human readablility) or not.
 
 @param port Can be 0 for a random port or a specific port.
 
 @return An @c NSError describing the error if there was one or @c nil if there was none.
 
 @see CocoaHTTPServer
 */

-(NSError *)startOnPort:(NSUInteger)port;

/**
 Stops broadcasting the NOStore over the network.
 */

-(void)stop;

/**
 Sets up the internal HTTP server's REST URL scheme.
 
 */

-(void)setupServerRoutes;

#pragma mark - Responding to requests

// code for handling incoming REST requests (authentication, returning JSON data)

/**
 All incoming REST requests (except for authentication requests) are handled by this method, which passes code execution to another of the following methods based on the request.
 
 */
-(void)handleRequest:(RouteRequest *)request
forResourceWithEntityDescription:(NSEntityDescription *)entityDescription
          resourceID:(NSNumber *)resourceID
            function:(NSString *)functionName
            response:(RouteResponse *)response;

/**
 Request handler for POST REST requests
 
 */
-(void)handleCreateResourceWithEntityDescription:(NSEntityDescription *)entityDescription
                                         session:(NSManagedObject<NOSessionProtocol> *)session
                                   initialValues:(NSDictionary *)initialValues
                                        response:(RouteResponse *)response;

/**
 Request handler for function REST requests
 
 */
-(void)handleFunction:(NSString *)functionName
   recievedJsonObject:(NSDictionary *)recievedJsonObject
             resource:(NSManagedObject<NOResourceProtocol> *)resource
              session:(NSManagedObject<NOSessionProtocol> *)session
             response:(RouteResponse *)response;

/**
 Request handler for PUT REST requests
 
 */
-(void)handleEditResource:(NSManagedObject <NOResourceProtocol> *)resource
       recievedJsonObject:(NSDictionary *)recievedJsonObject
                  session:(NSManagedObject <NOSessionProtocol> *)session
                 response:(RouteResponse *)response;

/**
 Request handler for GET REST requests
 
 */
-(void)handleGetResource:(NSManagedObject <NOResourceProtocol> *)resource
                 session:(NSManagedObject <NOSessionProtocol> *)session
                response:(RouteResponse *)response;

/**
 Request handler for DELETE REST requests
 
 */
-(void)handleDeleteResource:(NSManagedObject <NOResourceProtocol> *)resource
                    session:(NSManagedObject <NOSessionProtocol> *)session
                   response:(RouteResponse *)response;

/**
 Request handler for authentication requests
 
 */
-(void)handleLoginWithRequest:(RouteRequest *)request
                     response:(RouteResponse *)response;

#pragma mark - Common methods for handlers

/**
 Fetches a Session Resource that has the specified token.
 
 @return Returns an NSManagedObject subclass that conforms to NOSessionProtocol for the specified token or @c nil if none was found.
 
 */
-(NSManagedObject<NOSessionProtocol> *)sessionWithToken:(NSString *)token;

/**
 Generates a JSON representation of a NSManagedObject subclass that conforms to NOResourceProtocol based on the authentication of the user requesting the Resource instance.
 
 @return Returns an NSDictionary with values that are JSON compatible representing the Resource instance requested and filtering attributes or relationships that the requesting User does not that permission to view. 
 
 Note that attributes are converted from their Core Data value to a JSON compatible value and Transformable or Undefined attributes are ommitted. Relationships are represented by their Resource IDs.
 
 */

-(NSDictionary *)JSONRepresentationOfResource:(NSManagedObject<NOResourceProtocol> *)resource
                                   forSession:(NSManagedObject<NOSessionProtocol> *)session;

/**
 Goes through the JSON dictionary representing edit values a user submits and checks for the user's permission to change those values and if those values are valid.
 Returns a @c NOServerStatusCode based on the requesting user's permission to view the Resource.
 
 @return Returns @c OKStatusCode if the user can apply the edit,@c BadRequestStatusCode if the JSON object is invalid, or @c ForbiddenStatusCode if the user does not have permission the edit the values.
 
 @see NOServerStatusCode
 
 */

-(NOServerStatusCode)verifyEditResource:(NSManagedObject<NOResourceProtocol> *)resource
                     recievedJsonObject:(NSDictionary *)recievedJsonObject
                                session:(NSManagedObject<NOSessionProtocol> *)session;

/**
 Applies the the edits to a Resource from a valid JSON object. The JSON object should be verified first to avoid errors.
 
 */

-(void)setValuesForResource:(NSManagedObject<NOResourceProtocol> *)resource
             fromJSONObject:(NSDictionary *)jsonObject
                    session:(NSManagedObject<NOSessionProtocol> *)session;


@end
