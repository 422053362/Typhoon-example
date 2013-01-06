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
#import "SpringInjectedParameter.h"

@class SpringTypeDescriptor;


@interface SpringParameterInjectedByValue : NSObject <SpringInjectedParameter>
{
    __unsafe_unretained SpringComponentInitializer* _initializer;
}

@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly) SpringParameterInjectionType type;
@property(nonatomic, strong, readonly) NSString* value;
@property(nonatomic, strong, readonly) id classOrProtocol;

- (id)initWithIndex:(NSUInteger)index value:(NSString*)value classOrProtocol:(id)classOrProtocol;

/**
* If the parameter is a primitive type, resolves the type descriptor. Throws an exception if either:
* - classOrProtocol is set
* - The parameter is an object type. (If the parameter is an object type, classOrProtocol must be set explicitly).
*/
- (SpringTypeDescriptor*)resolveTypeWith:(id)classOrInstance;

@end