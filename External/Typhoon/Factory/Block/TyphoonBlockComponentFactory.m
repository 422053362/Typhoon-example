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



#import <objc/runtime.h>
#import <objc/message.h>
#import "TyphoonBlockComponentFactory.h"
#import "TyphoonAssembly.h"
#import "TyphoonDefinition.h"
#import "TyphoonJRSwizzle.h"
#import "OCLogTemplate.h"
#import "TyphoonAssemblySelectorWrapper.h"

static NSMutableArray* swizzleRegistry;

@interface TyphoonAssembly (BlockFactoryFriend)

+ (BOOL)selectorReserved:(SEL)selector;

- (NSMutableDictionary*)cachedDefinitionsForMethodName;

@end

@implementation TyphoonBlockComponentFactory

/* ====================================================================================================================================== */
#pragma mark - Class Methods

+ (void)initialize
{
    [super initialize];
    @synchronized (self)
    {
        swizzleRegistry = [[NSMutableArray alloc] init];
    }
}


+ (id)factoryWithAssembly:(TyphoonAssembly*)assembly
{
    return [[[self class] alloc] initWithAssembly:assembly];
}

/* ====================================================================================================================================== */
#pragma mark - Initialization & Destruction

- (id)initWithAssembly:(TyphoonAssembly*)assembly;
{
    LogTrace(@"Building assembly: %@", NSStringFromClass([assembly class]));
    if (![assembly isKindOfClass:[TyphoonAssembly class]])
    {
        [NSException raise:NSInvalidArgumentException format:@"Class '%@' is not a sub-class of %@", NSStringFromClass([assembly class]),
                                                             NSStringFromClass([TyphoonAssembly class])];
    }
    self = [super init];
    if (self)
    {
        [self applyBeforeAdviceToAssemblyMethods:assembly];
        NSArray* definitions = [self definitionsByPopulatingCache:assembly];
        for (TyphoonDefinition* definition in definitions)
        {
            [self register:definition];
        }
    }
    return self;
}

/* ====================================================================================================================================== */
#pragma mark - Overridden Methods

- (void)forwardInvocation:(NSInvocation*)invocation
{
    NSString* componentKey = NSStringFromSelector([invocation selector]);
    NSLog(@"Component key: %@", componentKey);

//    NSMutableArray* arguments = [[NSMutableArray alloc] init];
//    NSUInteger numberOfArguments = [[invocation methodSignature] numberOfArguments];
//    LogDebug(@"Number of arguments: %i", numberOfArguments);
//
//    for (int i = 2; i < numberOfArguments; i++)
//    {
//        id argument;
//        [invocation getArgument:&argument atIndex:i];
//        [arguments addObject:argument];
//    }
//
//    LogDebug(@"Runtime arguments: %@", arguments);

    [invocation setSelector:@selector(componentForKey:)];
    [invocation setArgument:&componentKey atIndex:2];
    [invocation invoke];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
    if ([self respondsToSelector:aSelector])
    {
        return [[self class] instanceMethodSignatureForSelector:aSelector];
    }
    else
    {
        return [[self class] instanceMethodSignatureForSelector:@selector(componentForKey:)];
    }
}


/* ====================================================================================================================================== */
#pragma mark - Private Methods

- (NSArray*)definitionsByPopulatingCache:(TyphoonAssembly*)assembly
{
    @synchronized (self)
    {
        NSSet* definitionSelectors = [self obtainDefinitionSelectors:assembly];

        [definitionSelectors enumerateObjectsUsingBlock:^(id obj, BOOL* stop)
        {
            objc_msgSend(assembly, (SEL) [obj pointerValue]);
        }];

        NSMutableDictionary* dictionary = [assembly cachedDefinitionsForMethodName];
        return [dictionary allValues];
    }
}

- (NSSet*)obtainDefinitionSelectors:(TyphoonAssembly*)assembly
{
    NSMutableSet* definitionSelectors = [[NSMutableSet alloc] init];
    [self addDefinitionSelectorsForSubclassesOfAssembly:assembly toSet:definitionSelectors];
    return definitionSelectors;
}

- (void)addDefinitionSelectorsForSubclassesOfAssembly:(TyphoonAssembly*)assembly toSet:(NSMutableSet*)definitionSelectors
{
    Class currentClass = [assembly class];
    while (strcmp(class_getName(currentClass), "TyphoonAssembly") != 0)
    {
        [definitionSelectors unionSet:[self obtainDefinitionSelectorsInAssemblyClass:currentClass]];
        currentClass = class_getSuperclass(currentClass);
    }
}

- (NSSet*)obtainDefinitionSelectorsInAssemblyClass:(Class)class
{
    NSMutableSet* definitionSelectors = [[NSMutableSet alloc] init];
    [self addDefinitionSelectorsInClass:class toSet:definitionSelectors];
    return definitionSelectors;
}

- (void)addDefinitionSelectorsInClass:(Class)aClass toSet:(NSMutableSet*)definitionSelectors
{
    [self enumerateMethodsInClass:aClass usingBlock:^(Method method)
    {
        if ([self method:method onClassIsNotReserved:aClass])
        {
            [self addDefinitionSelectorForMethod:method toSet:definitionSelectors];
        }
    }];
}

typedef void(^MethodEnumerationBlock)(Method method);

- (void)enumerateMethodsInClass:(Class)class usingBlock:(MethodEnumerationBlock)block;
{
    unsigned int methodCount;
    Method* methodList = class_copyMethodList(class, &methodCount);
    for (int i = 0; i < methodCount; i++)
    {
        Method method = methodList[i];
        block(method);
    }
    free(methodList);
}

- (BOOL)method:(Method)method onClassIsNotReserved:(Class)aClass;
{
    SEL methodSelector = method_getName(method);
    return ![aClass selectorReserved:methodSelector];
}

- (void)addDefinitionSelectorForMethod:(Method)method toSet:(NSMutableSet*)definitionSelectors
{
    SEL methodSelector = method_getName(method);
    [definitionSelectors addObject:[NSValue valueWithPointer:methodSelector]];
}

- (void)applyBeforeAdviceToAssemblyMethods:(TyphoonAssembly*)assembly
{
    @synchronized (self)
    {
        if (![swizzleRegistry containsObject:[assembly class]])
        {
            [swizzleRegistry addObject:[assembly class]];

            NSSet* definitionSelectors = [self obtainDefinitionSelectors:assembly];
            [definitionSelectors enumerateObjectsUsingBlock:^(id obj, BOOL* stop)
            {
                [self replaceImplementationOfDefinitionOnAssembly:assembly withDynamicBeforeAdviceImplementation:obj];
            }];
        }
    }
}

- (void)replaceImplementationOfDefinitionOnAssembly:(TyphoonAssembly*)assembly withDynamicBeforeAdviceImplementation:(id)obj;
{
    SEL methodSelector = (SEL) [obj pointerValue];
    SEL swizzled = [TyphoonAssemblySelectorWrapper wrappedSELForSEL:methodSelector];
    [[assembly class] typhoon_swizzleMethod:methodSelector withMethod:swizzled error:nil];
}

@end