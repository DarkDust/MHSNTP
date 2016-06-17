//
//  MHSNTPQueryOperation.m
//  MHSNTP
//
//  Created by Marc Haisenko on 06.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import "MHSNTPQueryOperation.h"

#import "MHSNTPLowLevel.h"


@interface MHSNTPQueryOperation ()
@property (copy) NSString * hostName;
@end

@implementation MHSNTPQueryOperation

- (instancetype)initWithServerName:(NSString *)hostName
{
    self = [super init];
    if (!self) return nil;
    
    self.hostName = hostName;
    
    return nil;
}

- (void)main
{
}


@end
