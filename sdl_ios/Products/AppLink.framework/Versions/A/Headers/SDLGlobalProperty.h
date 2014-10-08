//  SDLGlobalProperty.h
//  SyncProxy
//  Copyright (c) 2014 Ford Motor Company. All rights reserved.

#import <Foundation/Foundation.h>
#import <AppLink/SDLEnum.h>

@interface SDLGlobalProperty : SDLEnum {}

+(SDLGlobalProperty*) valueOf:(NSString*) value;
+(NSMutableArray*) values;

+(SDLGlobalProperty*) HELPPROMPT;
+(SDLGlobalProperty*) TIMEOUTPROMPT;
+(SDLGlobalProperty*) VRHELPTITLE;
+(SDLGlobalProperty*) VRHELPITEMS;
+(SDLGlobalProperty*) MENUNAME;
+(SDLGlobalProperty*) MENUICON;
+(SDLGlobalProperty*) KEYBOARDPROPERTIES;

@end
