//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 Jonathan M. Reid. See LICENSE.txt
//  Contribution by Igor Sales

#import "MKTSingletonSwizzler.h"

#import "MKTClassObjectMock.h"
#import <objc/runtime.h>


static NSMutableDictionary *singletonMap = nil;

static NSString *singletonKey(Class aClass, SEL aSelector)
{
    return [NSString stringWithFormat:@"%@-%@", aClass, NSStringFromSelector(aSelector)];
}


@interface MKTSingletonMapEntry : NSObject
{
@public
    __weak MKTClassObjectMock *_mock;
}

@property (nonatomic, weak, readonly) MKTClassObjectMock *mock;
@property (nonatomic, weak, readonly) Class mockedClass;
@property (nonatomic, assign, readonly) IMP oldIMP;
@property (nonatomic, assign, readonly) SEL selector;

@end


@implementation MKTSingletonMapEntry

- (instancetype)initWithMock:(MKTClassObjectMock *)mock IMP:(IMP)oldIMP selector:(SEL)aSelector
{
    self = [super init];
    if (self)
    {
        _mock = mock;
        _mockedClass = mock.mockedClass;
        _oldIMP = oldIMP;
        _selector = aSelector;
    }
    return self;
}

@end


@implementation MKTSingletonSwizzler

+ (void)initialize
{
    if (!singletonMap)
        singletonMap = [[NSMutableDictionary alloc] init];
}

+ (id)mockSingleton
{
    MKTSingletonMapEntry *singleton = singletonMap[singletonKey(self, _cmd)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [singleton.mock performSelector:_cmd withObject:nil];
#pragma clang diagnostic pop
}

- (void)dealloc
{
    [self unswizzleSingletonsForMock];
}

- (void)swizzleSingletonAtSelector:(SEL)singletonSelector
{
    MKTClassObjectMock *theMock = self.classMock;
    NSString *key = singletonKey(theMock.mockedClass, singletonSelector);
    
    Method origMethod = class_getClassMethod(theMock.mockedClass, singletonSelector);
    Method newMethod = class_getClassMethod([self class], @selector(mockSingleton));
    IMP oldIMP = method_getImplementation(origMethod);
    IMP newIMP = method_getImplementation(newMethod);
    method_setImplementation(origMethod, newIMP);
    
    MKTSingletonMapEntry *entry = singletonMap[key];
    if (entry)
        oldIMP = entry.oldIMP;
    
    singletonMap[key] = [[MKTSingletonMapEntry alloc] initWithMock:theMock
                                                               IMP:oldIMP
                                                          selector:singletonSelector];
}

- (void)unswizzleSingletonsForMock
{
    MKTClassObjectMock *theMock = self.classMock;
    NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
    
    [singletonMap enumerateKeysAndObjectsUsingBlock:^(NSString *key,
            MKTSingletonMapEntry *swizzled,
            BOOL *stop) {
        // At time of dealloc, it's possible the weak ref to swizzled.mock is nil,
        // so we also check directly on the struct member
        if (swizzled.mock == theMock || swizzled->_mock == theMock)
        {
            [self unswizzleSingletonFromEntry:swizzled];
            [keysToRemove addObject:key];
        }
    }];
    
    [singletonMap removeObjectsForKeys:keysToRemove];
}

- (void)unswizzleSingletonFromEntry:(MKTSingletonMapEntry *)swizzled
{
    Method origMethod = class_getClassMethod(swizzled.mockedClass, swizzled.selector);
    method_setImplementation(origMethod, swizzled.oldIMP);
}

@end