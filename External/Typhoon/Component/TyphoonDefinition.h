////////////////////////////////////////////////////////////////////////////////
//
//  JASPER BLUES
//  Copyright 2012 - 2013 Jasper Blues
//  All Rights Reserved.
//
//  NOTICE: Jasper Blues permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////




#import <Foundation/Foundation.h>

@class TyphoonInitializer;
@protocol TyphoonInjectedProperty;

typedef enum
{
    TyphoonComponentLifeCycleSingleton,
    TyphoonComponentLifeCyclePrototype
} TyphoonComponentLifecycle;


@interface TyphoonDefinition : NSObject
{
    NSMutableSet* _injectedProperties;
}

@property(nonatomic, readonly) Class type;
@property(nonatomic, strong) NSString* key;
@property(nonatomic, strong, readonly) NSString* factoryComponent;
@property(nonatomic, strong) TyphoonInitializer* initializer;
@property(nonatomic) SEL beforePropertyInjection;
@property(nonatomic) SEL afterPropertyInjection;
@property(nonatomic, strong, readonly) NSSet* injectedProperties;
@property(nonatomic) TyphoonComponentLifecycle lifecycle;


- (id)initWithClass:(Class)clazz key:(NSString*)key;

- (id)initWithClass:(Class)clazz key:(NSString*)key factoryComponent:(NSString*)factoryComponent;

- (void)injectProperty:(SEL)withSelector;

- (void)injectProperty:(SEL)withSelector withReference:(NSString*)reference;

- (void)injectProperty:(SEL)withSelector withValueAsText:(NSString*)textValue;

- (void)addInjectedProperty:(id <TyphoonInjectedProperty>)property;

- (NSSet*)propertiesInjectedByValue;

- (NSSet*)propertiesInjectedByType;

- (NSSet*)propertiesInjectedByReference;

@end