//  SDLGetDTCsResponse.m
//


#import "SDLGetDTCsResponse.h"

#import "SDLNames.h"

@implementation SDLGetDTCsResponse

- (instancetype)init {
    if (self = [super initWithName:SDLNameGetDTCs]) {
    }
    return self;
}

- (instancetype)initWithDictionary:(NSMutableDictionary<NSString *, id> *)dict {
    if (self = [super initWithDictionary:dict]) {
    }
    return self;
}

- (void)setEcuHeader:(NSNumber *)ecuHeader {
    if (ecuHeader != nil) {
        [parameters setObject:ecuHeader forKey:SDLNameECUHeader];
    } else {
        [parameters removeObjectForKey:SDLNameECUHeader];
    }
}

- (NSNumber *)ecuHeader {
    return [parameters objectForKey:SDLNameECUHeader];
}

- (void)setDtc:(NSMutableArray<NSString *> *)dtc {
    if (dtc != nil) {
        [parameters setObject:dtc forKey:SDLNameDTC];
    } else {
        [parameters removeObjectForKey:SDLNameDTC];
    }
}

- (NSMutableArray<NSString *> *)dtc {
    return [parameters objectForKey:SDLNameDTC];
}

@end
