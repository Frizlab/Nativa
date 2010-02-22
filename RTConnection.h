//
//  RTConnection.h
//  Nativa
//
//  Created by Vladimir Solomenchuk on 12.01.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AMSession;

@interface RTConnection : NSObject 
{
	NSString* hostName;
	int port;
	AMSession* _proxy;
	BOOL _connected;
}
- (id)initWithHostPort:(NSString *)initHost port:(int)initPort proxy:(AMSession*) proxy;

- (BOOL) openStreams:(NSInputStream **)iStream oStream:(NSOutputStream **) oStream delegate:(id) delegate;

-(void) closeConnection;

-(void) openConnection;

@property (readonly) BOOL connected;
@end
