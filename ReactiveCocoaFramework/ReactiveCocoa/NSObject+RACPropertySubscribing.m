//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import <objc/runtime.h>
#import "NSObject+RACKVOWrapper.h"
#import "RACValueTransformer.h"
#import "RACReplaySubject.h"
#import "RACDisposable.h"
#import "RACSwizzling.h"
#import "RACSubscribable+Private.h"

static NSMutableDictionary *swizzledClasses = nil;

static const void *RACPropertySubscribingDisposables = &RACPropertySubscribingDisposables;


@implementation NSObject (RACPropertySubscribing)

+ (void)load {
	swizzledClasses = [[NSMutableDictionary alloc] init];
}

- (void)rac_propertySubscribingDealloc {
	NSMutableSet *disposables = objc_getAssociatedObject(self, RACPropertySubscribingDisposables);
	for(RACDisposable *disposable in [disposables copy]) {
		[disposable dispose];
	}
	
	objc_setAssociatedObject(self, RACPropertySubscribingDisposables, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_propertySubscribingDealloc];
}

+ (RACSubscribable *)RACSubscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	
	@synchronized(swizzledClasses) {
		Class class = [onObject class];
		NSString *keyName = NSStringFromClass(class);
		if([swizzledClasses objectForKey:keyName] == nil) {
			RACSwizzle(class, NSSelectorFromString(@"dealloc"), @selector(rac_propertySubscribingDealloc));
			[swizzledClasses setObject:[NSNull null] forKey:keyName];
		}
	}
	
	@synchronized(self) {
		NSMutableSet *disposables = objc_getAssociatedObject(onObject, RACPropertySubscribingDisposables);
		if(disposables == nil) {
			disposables = [NSMutableSet set];
			objc_setAssociatedObject(onObject, RACPropertySubscribingDisposables, disposables, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		
		[disposables addObject:[RACDisposable disposableWithBlock:^{
			// tear down the subscribable without sending notifications to the subscribers, since they could have already been dealloc'd by this point
			[subject tearDown];
		}]];
	}
	
	__block __unsafe_unretained NSObject *weakObject = object;
	[object rac_addObserver:onObject forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongObject = weakObject;
		[subject sendNext:[strongObject valueForKeyPath:keyPath]];
	}];
	
	return subject;
}

- (RACSubscribable *)RACSubscribableForKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
	return [[self class] RACSubscribableFor:self keyPath:keyPath onObject:object];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath nilValue:nil];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock {
	RACValueTransformer *transformer = [RACValueTransformer transformerWithBlock:transformBlock];
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, transformer, NSValueTransformerBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
}

@end
