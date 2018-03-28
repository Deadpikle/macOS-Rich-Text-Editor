//
//  WZProtocolInterceptor.h
//
//  Created by WeZZard on 10/13/13.
//  Copyright © 2013 WeZZard. All rights reserved.
//  http://stackoverflow.com/a/18777565/3938401

#import <Foundation/Foundation.h>

@interface WZProtocolInterceptor : NSObject

@property (nonatomic, readonly, copy) NSArray * interceptedProtocols;
@property (unsafe_unretained) id receiver;
@property (unsafe_unretained) id middleMan;

- (instancetype)initWithInterceptedProtocol:(Protocol *)interceptedProtocol;
- (instancetype)initWithInterceptedProtocols:(Protocol *)firstInterceptedProtocol, ... NS_REQUIRES_NIL_TERMINATION;
- (instancetype)initWithArrayOfInterceptedProtocols:(NSArray *)arrayOfInterceptedProtocols;

@end
