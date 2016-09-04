//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 Jonathan M. Reid. See LICENSE.txt
//  Contribution by Igor Sales

#import <objc/runtime.h>
#import "MKTSwizzler.h"

#import "MKTClassObjectMock.h"


NSMutableDictionary *singletonMap = nil;

NSString *singletonKey(Class aClass, SEL aSelector)
{
    return [NSString stringWithFormat:@"%@-%@", aClass, NSStringFromSelector(aSelector)];
}


@interface MKTClassObjectMockMapEntry2 : NSObject
{
@public
    __weak MKTClassObjectMock *_mock;
}

@property (nonatomic, weak, readonly) MKTClassObjectMock *mock;
@property (nonatomic, weak, readonly) Class mockedClass;
@property (nonatomic, assign, readonly) IMP oldIMP;
@property (nonatomic, assign, readonly) SEL selector;

@end

@implementation MKTClassObjectMockMapEntry2

- (instancetype)initWithMock:(MKTClassObjectMock *)mock IMP:(IMP)oldIMP selector:(SEL)selector
{
    self = [super init];
    if (self)
    {
        _mock = mock;
        _mockedClass = mock.mockedClass;
        _oldIMP = oldIMP;
        _selector = selector;
    }
    return self;
}

@end


@implementation MKTSwizzler

+ (void)initialize
{
    if (!singletonMap)
        singletonMap = [[NSMutableDictionary alloc] init];
}

- (void)swizzleSingletonAtSelector:(SEL)singletonSelector toMock:(MKTClassObjectMock *)theMock
{
    NSString *key = singletonKey(theMock.mockedClass, singletonSelector);
    
    Method origMethod = class_getClassMethod(theMock.mockedClass, singletonSelector);
    Method newMethod = class_getClassMethod([theMock class], @selector(mockSingleton));
    
    IMP oldIMP = method_getImplementation(origMethod);
    IMP newIMP = method_getImplementation(newMethod);
    
    method_setImplementation(origMethod, newIMP);
    
    MKTClassObjectMockMapEntry2 *entry = singletonMap[key];
    if (entry)
    {
        // The user has already swizzled this singleton, keep the original implementation
        oldIMP = entry.oldIMP;
    }
    
    singletonMap[key] = [[MKTClassObjectMockMapEntry2 alloc] initWithMock:theMock
                                                                     IMP:oldIMP
                                                                selector:singletonSelector];
}

@end