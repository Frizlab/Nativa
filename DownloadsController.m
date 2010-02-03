//
//  DownloadsController.m
//  Nativa
//
//  Created by Vladimir Solomenchuk on 27.01.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import "DownloadsController.h"
#import "SynthesizeSingleton.h"
#import "Torrent.h"
#import "TorrentDelegate.h"
#import "ProcessesController.h"
#import "ProcessDescriptor.h"

NSString* const NINotifyUpdateDownloads = @"NINotifyUpdateDownloads";

@interface DownloadsController(Private)

- (void)_updateList;

- (id<TorrentController>) _controller;

@end

@implementation DownloadsController

SYNTHESIZE_SINGLETON_FOR_CLASS(DownloadsController);

@synthesize	globalUploadSpeed = _globalUploadSpeed;
@synthesize globalDownloadSpeed = _globalDownloadSpeed;


-(id)init;
{
	self = [super init];
	if (self == nil)
		return nil;
	_downloads = [[[NSMutableArray alloc] init] retain];
	return self;
}


-(void)dealloc
{
	[_downloads release];
	[super dealloc];
}

#pragma mark -
#pragma mark public methods

-(void) startUpdates;
{
	[_updateListTimer invalidate];
	_updateListTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_updateList) userInfo:nil repeats:YES];
	[_updateListTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:_updateListTimer forMode:NSDefaultRunLoopMode];	
}
-(void) stopUpdates;
{
	[_updateListTimer invalidate];
}

-(NSArray*) downloads;
{
	return _downloads;
}

#pragma mark -
#pragma mark concrete torrent methods

- (void) start:(NSString *) hash response:(VoidResponseBlock) response
{
	[[self _controller] start:hash response:response];
}

- (void) stop:(NSString *) hash response:(VoidResponseBlock) response
{
	[[self _controller] stop:hash response:response];
}

- (void) add:(NSArray *) filesNames
{
	for(NSString *file in filesNames)
	{
		NSURL* url = [NSURL fileURLWithPath:file];
		NSArray* urls = [NSArray arrayWithObjects:url, nil];
		__block DownloadsController *blockSelf = self;
		VoidResponseBlock response = [^{ 
#warning memory leak here (recycleURLs)
				[[NSWorkspace sharedWorkspace] recycleURLs: urls
							completionHandler:nil];
		} copy];
		[[self _controller] add:url response:response];
		[response release];
	}
}

- (void) erase:(NSString *) hash response:(VoidResponseBlock) response
{
	[[self _controller] erase:hash response:response];
}

#pragma mark -
#pragma mark global state methods

- (void) setGlobalDownloadSpeedLimit:(int) speed response:(VoidResponseBlock) response
{
	[[self _controller] setGlobalDownloadSpeedLimit:speed response:response];
}

- (void) getGlobalDownloadSpeedLimit:(NumberResponseBlock) response
{
	[[self _controller] getGlobalDownloadSpeedLimit:response];
}
@end

@implementation DownloadsController(Private)
- (id<TorrentController>) _controller
{
	ProcessDescriptor *p=[[ProcessesController sharedProcessesController] processDescriptorAtIndex:0];
	return [p process];
}

- (void)_updateList
{
	__block DownloadsController *blockSelf = self;
	ArrayResponseBlock response = [^(NSArray *array, NSString* error) {
		if (error != nil)
			return;
		NSUInteger idx;
#warning multiple objects?
		Torrent* stored_obj;
		CGFloat globalUploadRate = 0.0;
		CGFloat globalDownloadRate = 0.0;
		for (Torrent *obj in array)
		{
			idx = [blockSelf->_downloads indexOfObject:obj];
			if (idx ==  NSNotFound)
				[blockSelf->_downloads addObject:obj];
			else 
			{
				stored_obj = [blockSelf->_downloads objectAtIndex:idx];
				[stored_obj update:obj];
				[obj release];
			}
			globalUploadRate += [obj speedUpload];
			globalDownloadRate += [obj speedDownload];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName: NINotifyUpdateDownloads object: blockSelf];
		blockSelf.globalDownloadSpeed = globalDownloadRate;
		blockSelf.globalUploadSpeed = globalUploadRate;
	} copy];
	[[self _controller] list:response];
	[response release];
}
@end