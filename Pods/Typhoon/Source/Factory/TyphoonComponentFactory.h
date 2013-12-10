////////////////////////////////////////////////////////////////////////////////
//
//  TYPHOON FRAMEWORK
//  Copyright 2013, Jasper Blues & Contributors
//  All Rights Reserved.
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////



#import <Foundation/Foundation.h>
#import "TyphoonComponentFactoryPostProcessor.h"
#import "TyphoonInstanceRegister.h"

@class TyphoonDefinition;

/**
*
* @ingroup Factory
*
* This is the base class for all component factories. It defines methods for retrieving components from the factory, as well as a low-level
* API for assembling components from their constituent parts. This low-level API could be used as-is, however its intended to use a higher
* level abstraction such as TyphoonBlockComponentFactory or TyphoonXmlComponentFactory.
*/
@interface TyphoonComponentFactory : NSObject
{
    NSMutableArray* _registry;
    NSMutableDictionary* _singletons;

    id <TyphoonInstanceRegister> _currentlyResolvingReferences;
    NSMutableArray* _postProcessors;
    BOOL _isLoading;
}

/**
* The instantiated singletons.
*/
@property(nonatomic, strong, readonly) NSArray* singletons;

/**
* Say if the factory has been loaded.
*/
@property(nonatomic, assign, getter = isLoaded) BOOL loaded;

/**
 * The attached factory post processors.
 */
@property(nonatomic, strong, readonly) NSArray* postProcessors;

/**
* Returns the default component factory, if one has been set. (See makeDefault ).
*/
+ (id)defaultFactory;

/**
* Mutate the component definitions and
* build the not-lazy singletons.
*/
- (void)load;

/**
* Dump all the singletons.
*/
- (void)unload;

/**
* Sets a given instance of TyphoonComponentFactory, as the default factory so that it can be retrieved later with:
*
*       [TyphoonComponentFactory defaultFactory];
*
*/
- (void)makeDefault;

/**
* Registers a component into the factory. Components can be declared in any order, the container will work out how to resolve them.
*/
- (void)register:(TyphoonDefinition*)definition;

/**
* Returns an an instance of the component matching the supplied class or protocol. For example:

        [factory objectForType:[Knight class]];
        [factory objectForType:@protocol(Quest)];

* @exception NSInvalidArgumentException When no singletons or prototypes match the requested type.
* @exception NSInvalidArgumentException When when more than one singleton or prototype matches the requested type.
*
* @See: allComponentsForType:
*/
- (id)componentForType:(id)classOrProtocol;

- (NSArray*)allComponentsForType:(id)classOrProtocol;

/**
* Returns the component matching the given key. For XML-style, this is the key specified as the 'id' attribute. For the block-style, this
* is the name of the method on the TyphoonAssembly interface, although, for block-style you'd typically use the assembly interface itself
* for component resolution.
*/
- (id)componentForKey:(NSString*)key;

- (NSArray*)registry;

/**
 Attach a TyphoonComponentFactoryPostProcessor to this component factory.
 @param postProcessor The post-processor to attach.
 */
- (void)attachPostProcessor:(id <TyphoonComponentFactoryPostProcessor>)postProcessor;

/**
 * Injects the properties of an object
 */
- (void)injectProperties:(id)instance;

@end
