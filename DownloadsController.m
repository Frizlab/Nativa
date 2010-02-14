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
#import "PreferencesController.h"

NSString* const NINotifyUpdateDownloads = @"NINotifyUpdateDownloads";

@interface DownloadsController(Private)

- (void)_updateList;

- (id<TorrentController>) _controller;

- (VoidResponseBlock) _updateListResponse: (VoidResponseBlock) originalResponse;
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
	_defaults = [NSUserDefaults standardUserDefaults];
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
	ProcessesController* pc = [ProcessesController sharedProcessesController];
	
	for (NSInteger i=0;i<[pc count];i++)
	{
		ProcessDescriptor* pd =[pc processDescriptorAtIndex:i];
		[pd closeProcess];
	}
}

-(NSArray*) downloads;
{
	return _downloads;
}

#pragma mark -
#pragma mark concrete torrent methods

- (void) start:(NSString *) hash response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response];
	[[self _controller] start:hash response:r];
	[r release];
}

- (void) stop:(NSString *) hash response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response];
	[[self _controller] stop:hash response:r];
	[r release];
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
			if ([_defaults boolForKey:NITrashDownloadDescriptorsKey])
			{
				[[NSWorkspace sharedWorkspace] recycleURLs: urls
										  completionHandler:nil];
			}
			
			[blockSelf _updateList];
		} copy];
		[[self _controller] add:url response:response];
		[response release];
	}
}

- (void) erase:(NSString *) hash response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response];
	[[self _controller] erase:hash response:[self _updateListResponse:r]];
	[r release];
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

- (BOOL) reveal:(Torrent*) torrent
{
	ProcessDescriptor *pd = [[ProcessesController sharedProcessesController] processDescriptorAtIndex:0];
	NSString * location = pd.downloadsFolder;
	if (location)
	{
		NSMutableString* exactLocation = [NSMutableString stringWithCapacity:[location length]];
		NSArray* splittedPath = [torrent.dataLocation pathComponents];
		
		[exactLocation setString:location];
		
		NSFileManager* dm = [NSFileManager defaultManager];
		
		for(int i=[splittedPath count]-1;i>-1;i--) //we do not know where is file, so lets make some guesses
		{
			for (int ii = i;ii<[splittedPath count];ii++)
				[exactLocation appendFormat:@"/%@",[splittedPath objectAtIndex:ii]];

			if ([dm fileExistsAtPath:exactLocation])
				break;
			else
				[exactLocation setString:location];

		}
		
		if ([dm fileExistsAtPath:exactLocation])
		{
			NSURL * file = [NSURL fileURLWithPath: exactLocation];
			[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: [NSArray arrayWithObject: file]];
			return YES;
		}
	}
	
	return NO;
}

-(void) setPriority:(Torrent *)torrent  priority:(TorrentPriority)priority response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response];
	[[self _controller] setPriority:torrent priority:priority response:r];
	[r release];
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
		
		//find removed torrents
		NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity: [blockSelf->_downloads count]];
		for (Torrent *obj in blockSelf->_downloads)
		{
			idx = [array indexOfObject:obj];
			if (idx ==  NSNotFound)
				[toRemove addObject:obj];
		}
		
		for (Torrent *obj in toRemove)
		{
			[blockSelf->_downloads removeObject:obj];
			[obj release];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName: NINotifyUpdateDownloads object: blockSelf];
		blockSelf.globalDownloadSpeed = globalDownloadRate;
		blockSelf.globalUploadSpeed = globalUploadRate;
	} copy];
	[[self _controller] list:response];
	[response release];
}

- (VoidResponseBlock) _updateListResponse: (VoidResponseBlock) originalResponse
{
	__block DownloadsController *blockSelf = self;
	return [^(NSString* error){
		if (originalResponse)
			originalResponse(error);
		if (error)
			NSLog(@"last operation error: %@", error);
		[blockSelf _updateList];
	}copy];
}
@end