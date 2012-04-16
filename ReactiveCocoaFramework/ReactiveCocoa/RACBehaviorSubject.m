//
//  RACBehaviorSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBehaviorSubject.h"

@interface RACBehaviorSubject ()
@property (nonatomic, strong) id currentValue;
@end


@implementation RACBehaviorSubject


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)observer {
	RACDisposable * disposable = [super subscribe:observer];
	[observer sendNext:self.currentValue];
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[super sendNext:value];
	
	self.currentValue = value;
}


#pragma mark API

@synthesize currentValue;

+ (id)behaviorSubjectWithDefaultValue:(id)value {
	RACBehaviorSubject *subject = [self subject];
	subject.currentValue = value;
	return subject;
}

@end
