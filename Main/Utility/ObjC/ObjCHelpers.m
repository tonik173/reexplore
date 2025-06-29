//
//  ObjCHelpers.m
//  Reexplore
//
//  Created by Toni Kaufmann on 04.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "ObjCHelpers.h"

@interface ObjCHelpers()
@end

@implementation ObjCHelpers

+ (NSString*)compileDate
{
    return [NSString stringWithUTF8String:__DATE__];
}
    
+ (NSString*)compileTime
{
    return [NSString stringWithUTF8String:__TIME__];
}

@end
