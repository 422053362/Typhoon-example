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


#import "TyphoonAssemblySelectorAdviser.h"
#import "TyphoonAssemblyAdviser.h"
#import "TyphoonAssembly.h"
#import "TyphoonJRSwizzle.h"
#import <objc/runtime.h>
#import "TyphoonAssembly+TyphoonAssemblyFriend.h"
#import "OCLogTemplate.h"

static NSMutableDictionary* swizzledDefinitionsByAssemblyClass;


@implementation TyphoonAssemblyAdviser
{

}

+ (void)initialize
{
    @synchronized (self)
    {
        swizzledDefinitionsByAssemblyClass = [[NSMutableDictionary alloc] init];
    }
}

#pragma mark - Advising
+ (void)adviseMethods:(TyphoonAssembly*)assembly
{
    @synchronized (self)
    {
        if ([TyphoonAssemblyAdviser assemblyIsNotAdvised:assembly])
        {
            [self swizzleAssemblyMethods:assembly];
        }
    }
}

+ (void)undoAdviseMethods:(TyphoonAssembly*)assembly
{
    @synchronized (self)
    {
        if ([TyphoonAssemblyAdviser assemblyIsAdvised:assembly])
        {
            [self unswizzleAssemblyMethods:assembly];
        }
    }
}

+ (void)unswizzleAssemblyMethods:(TyphoonAssembly*)assembly
{
    NSSet* swizzledSelectors = [swizzledDefinitionsByAssemblyClass objectForKey:NSStringFromClass([assembly class])];

    LogTrace(@"Unswizzling the following selectors: '%@' on assembly: '%@'.", [self humanReadableDescriptionForSelectorObjects:swizzledSelectors], assembly);

    [self swizzleDefinitionSelectors:swizzledSelectors onAssembly:assembly];

    [self markAssemblyMethodsAsNoLongerAdvised:assembly];
}

+ (NSString*)humanReadableDescriptionForSelectorObjects:(NSSet*)selectors
{
    NSMutableSet* selectorStrings = [[NSMutableSet alloc] initWithCapacity:selectors.count];
    [selectors enumerateObjectsUsingBlock:^(NSValue* obj, BOOL* stop)
    {
        SEL sel = [obj pointerValue];
        NSString* string = NSStringFromSelector(sel);
        [selectorStrings addObject:string];
    }];

    return [selectorStrings description];
}

+ (void)swizzleAssemblyMethods:(TyphoonAssembly*)assembly
{
    NSSet* definitionSelectors = [self definitionSelectorsForAssembly:assembly];
    LogTrace(@"About to swizzle the following methods: %@.", [self humanReadableDescriptionForSelectorObjects:definitionSelectors]);

    [self swizzleDefinitionSelectors:definitionSelectors onAssembly:assembly];

    [self markAssemblyMethods:definitionSelectors asAdvised:assembly];
}

+ (void)swizzleDefinitionSelectors:(NSSet*)definitionSelectors onAssembly:(TyphoonAssembly*)assembly
{
    [definitionSelectors enumerateObjectsUsingBlock:^(NSValue* selectorObj, BOOL* stop)
    {
        [self swapImplementationOfDefinitionSelector:selectorObj withDynamicBeforeAdviceImplementationOnAssembly:assembly];
    }];
}

+ (void)swapImplementationOfDefinitionSelector:(NSValue*)obj withDynamicBeforeAdviceImplementationOnAssembly:(TyphoonAssembly*)assembly
{
    return [self swapImplementationOfDefinitionSelector:obj withDynamicBeforeAdviceImplementationOnAssemblyClass:[assembly class]];
}

+ (void)swapImplementationOfDefinitionSelector:(NSValue*)obj withDynamicBeforeAdviceImplementationOnAssemblyClass:(Class)assemblyClass
{
    SEL methodSelector = (SEL)[obj pointerValue];
    SEL swizzled = [TyphoonAssemblySelectorAdviser advisedSELForSEL:methodSelector];

    NSError* err;
    BOOL success = [assemblyClass typhoon_swizzleMethod:methodSelector withMethod:swizzled error:&err];
    if (!success)
    {
        LogError(@"Failed to swizzle method '%@' on class '%@' with method '%@'.", NSStringFromSelector(methodSelector), NSStringFromClass(assemblyClass), NSStringFromSelector(swizzled));
        LogError(@"'%@'", err);
        [NSException raise:NSInternalInconsistencyException format:@"Failed to swizzle method, everything is broken!"];
    }
}

#pragma mark - Definition Selector Enumerator
+ (NSSet*)definitionSelectorsForAssembly:(TyphoonAssembly*)assembly
{
    NSMutableSet* definitionSelectors = [[NSMutableSet alloc] init];
    [self addDefinitionSelectorsForSubclassesOfAssembly:assembly toSet:definitionSelectors];
    return definitionSelectors;
}

+ (void)addDefinitionSelectorsForSubclassesOfAssembly:(TyphoonAssembly*)assembly toSet:(NSMutableSet*)definitionSelectors
{
    Class currentClass = [assembly class];
    while ([self classNotRootAssemblyClass:currentClass])
    {
        [definitionSelectors unionSet:[self obtainDefinitionSelectorsInAssemblyClass:currentClass]];
        currentClass = class_getSuperclass(currentClass);
    }
}

+ (NSSet*)obtainDefinitionSelectorsInAssemblyClass:(Class)pClass
{
    NSMutableSet* definitionSelectors = [[NSMutableSet alloc] init];
    [self addDefinitionSelectorsInClass:pClass toSet:definitionSelectors];
    return definitionSelectors;
}

+ (void)addDefinitionSelectorsInClass:(Class)aClass toSet:(NSMutableSet*)definitionSelectors
{
    [self enumerateMethodsInClass:aClass usingBlock:^(Method method)
    {
        if ([self method:method onClassIsNotReserved:aClass] && [self method:method onClassIsNotAdvised:aClass])
        {
            [self addDefinitionSelectorForMethod:method toSet:definitionSelectors];
        }
    }];
}

+ (BOOL)method:(Method)pMethod onClassIsNotAdvised:(Class)advised
{
    SEL sel = method_getName(pMethod);
    return ![TyphoonAssemblySelectorAdviser selectorIsAdvised:sel];
}

typedef void(^MethodEnumerationBlock)(Method method);

+ (void)enumerateMethodsInClass:(Class)class usingBlock:(MethodEnumerationBlock)block;
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

+ (BOOL)method:(Method)method onClassIsNotReserved:(Class)aClass
{
    SEL methodSelector = method_getName(method);
    return ![aClass selectorReservedOrPropertySetter:methodSelector];
}

+ (BOOL)classNotRootAssemblyClass:(Class)currentClass;
{
    NSString* currentClassName = NSStringFromClass(currentClass);
    NSString* rootAssemblyClassName = NSStringFromClass([TyphoonAssembly class]);

    return ![currentClassName isEqualToString:rootAssemblyClassName];
}

+ (void)addDefinitionSelectorForMethod:(Method)method toSet:(NSMutableSet*)definitionSelectors
{
    SEL methodSelector = method_getName(method);
    [definitionSelectors addObject:[NSValue valueWithPointer:methodSelector]];
}

#pragma mark - Advising Registry
+ (BOOL)assemblyIsNotAdvised:(TyphoonAssembly*)assembly;
{
    return ![self assemblyIsAdvised:assembly];
}

+ (BOOL)assemblyIsAdvised:(TyphoonAssembly*)assembly
{
    return [self assemblyClassIsAdvised:[assembly class]];
}

+ (BOOL)assemblyClassIsAdvised:(Class)class
{
    return [[swizzledDefinitionsByAssemblyClass allKeys] containsObject:NSStringFromClass(class)];
}

+ (void)markAssemblyMethods:(NSSet*)definitionSelectors asAdvised:(TyphoonAssembly*)assembly;
{
    [swizzledDefinitionsByAssemblyClass setObject:definitionSelectors forKey:NSStringFromClass([assembly class])];
}

+ (void)markAssemblyMethodsAsNoLongerAdvised:(TyphoonAssembly*)assembly;
{
    [swizzledDefinitionsByAssemblyClass removeObjectForKey:NSStringFromClass([assembly class])];
}

@end