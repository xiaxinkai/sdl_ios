//  SDLAlertManeuver.h
//  SyncProxy
//  Copyright (c) 2014 Ford Motor Company. All rights reserved.

#import <Foundation/Foundation.h>
#import <AppLink/SDLRPCRequest.h>

@interface SDLAlertManeuver : SDLRPCRequest {}

-(id) init;
-(id) initWithDictionary:(NSMutableDictionary*) dict;

@property(strong) NSMutableArray* ttsChunks;
@property(strong) NSMutableArray* softButtons;

@end
