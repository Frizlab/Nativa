//
//  TorrentData.h
//  Nativa
//
//  Created by Vladimir Solomenchuk on 06.01.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TorrentState.h"

@interface TorrentItem : NSObject 
{
	NSProgressIndicator *progress;
	
	NSString* name;
	
	NSString* thash;
	
	unsigned long int size;
	
	enum TorrentState state;
}
@property (readwrite, retain) NSString* name;
@property (readwrite, retain) NSString* thash;
@property int downloaded;
@property int uploaded;
@property unsigned long int size;
@property (readwrite, retain) NSProgressIndicator *progress;
@property enum TorrentState state;

- (void) update: (TorrentItem *) anotherItem;
- (double) donePercent;
@end