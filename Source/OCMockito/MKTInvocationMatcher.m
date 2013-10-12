//
//  OCMockito - MKTInvocationMatcher.m
//  Copyright 2013 Jonathan M. Reid. See LICENSE.txt
//
//  Created by: Jon Reid, http://qualitycoding.org/
//  Source: https://github.com/jonreid/OCMockito
//

#import "MKTInvocationMatcher.h"

#import "MKTCapturingMatcher.h"
#import "NSInvocation+TKAdditions.h"

#if TARGET_OS_MAC
    #import <OCHamcrest/OCHamcrest.h>
    #import <OCHamcrest/HCWrapInMatcher.h>
#else
    #import <OCHamcrestIOS/OCHamcrestIOS.h>
    #import <OCHamcrestIOS/HCWrapInMatcher.h>
#endif


@implementation MKTInvocationMatcher

- (instancetype)init
{
    self = [super init];
    if (self)
        _argumentMatchers = [[NSMutableArray alloc] init];
    return self;
}

- (void)setMatcher:(id <HCMatcher>)matcher atIndex:(NSUInteger)index
{
    if (index < [self.argumentMatchers count])
        [self.argumentMatchers replaceObjectAtIndex:index withObject:matcher];
    else
    {
        [self trueUpArgumentMatchersToCount:index];
        [self.argumentMatchers addObject:matcher];
    }
}

- (NSUInteger)argumentMatchersCount
{
    return [self.argumentMatchers count];
}

- (void)trueUpArgumentMatchersToCount:(NSUInteger)desiredCount
{
    NSUInteger count = [self.argumentMatchers count];
    while (count < desiredCount)
    {
        [self.argumentMatchers addObject:[self placeholderForUnspecifiedMatcher]];
        ++count;
    } 
}

- (void)setExpectedInvocation:(NSInvocation *)expectedInvocation
{
    self.expected = expectedInvocation;
    [self.expected retainArguments];

    self.numberOfArguments = [[self.expected methodSignature] numberOfArguments] - 2;
    [self trueUpArgumentMatchersToCount:self.numberOfArguments];
    [self replacePlaceholdersWithEqualityMatchersForArguments:[self.expected tk_arrayArguments]];
}

- (void)replacePlaceholdersWithEqualityMatchersForArguments:(NSArray *)expectedArgs
{
    for (NSUInteger index = 0; index < self.numberOfArguments; ++index)
    {
        if (self.argumentMatchers[index] == [self placeholderForUnspecifiedMatcher])
            [self.argumentMatchers replaceObjectAtIndex:index withObject:[self matcherForArgument:expectedArgs[index]]];
    }
}

- (id)placeholderForUnspecifiedMatcher
{
    return [NSNull null];
}

- (id <HCMatcher>)matcherForArgument:(id)arg
{
    if (arg == [NSNull null])
        return HC_nilValue();
    else
        return HCWrapInMatcher(arg);
}

- (BOOL)matches:(NSInvocation *)actual
{
    if ([self.expected selector] != [actual selector])
        return NO;

    NSArray *actualArgs = [actual tk_arrayArguments];
    for (NSUInteger index = 0; index < self.numberOfArguments; ++index)
    {
        if ([self argument:actualArgs[index] doesNotMatch:self.argumentMatchers[index]])
            return NO;
    }
    return YES;
}

- (BOOL)argument:(id)arg doesNotMatch:(id <HCMatcher>)matcher
{
    if (arg == [NSNull null])
        arg = nil;
    return ![matcher matches:arg];
}

- (void)captureArgumentsFromInvocations:(NSArray *)invocations
{
    for (NSUInteger index = 0; index < self.numberOfArguments; ++index)
    {
        id <HCMatcher> matcher = self.argumentMatchers[index];
        if ([matcher respondsToSelector:@selector(captureArgument:)])
        {
            NSUInteger indexWithHiddenArgs = index + 2;
            for (NSInvocation *inv in invocations)
            {
                __unsafe_unretained id actualArg;
                [inv getArgument:&actualArg atIndex:indexWithHiddenArgs];
                [matcher performSelector:@selector(captureArgument:) withObject:actualArg];
            }
        }
    }
}

@end
