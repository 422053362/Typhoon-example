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


#import "SpringBundleResource.h"


@implementation SpringBundleResource

/* =========================================================== Class Methods ============================================================ */
+ (id<SpringResource>)withName:(NSString*)name {

    NSString* contents;
    NSRange lastDot = [name rangeOfString:@"." options:NSBackwardsSearch];
    if (lastDot.location != NSNotFound) {
        NSString* resource = [name substringToIndex:lastDot.location];
        NSString* type = [name substringFromIndex:lastDot.location + 1];
        NSLog(@"Resource: %@.%@", resource, type);
        NSString* filePath = [[NSBundle bundleForClass:[self class]] pathForResource:resource ofType:type];
        contents =  [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    }
    else {
        NSString* filePath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:nil];
        contents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    }
    if (contents == nil) {
        [NSException raise:NSInvalidArgumentException format:@"Expected contents of file %@ not to be nil", name];
    }
    return [[[self class] alloc] initWithStringValue:contents];
}

/* ============================================================ Initializers ============================================================ */
- (id)initWithStringValue:(NSString*)stringValue
{
    self = [super init];
    if (self)
    {
        _stringValue = stringValue;
    }

    return self;
}

- (NSString*)asString
{
    return _stringValue;
}


@end