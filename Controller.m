//
//  Controller.m
//  Nativa
//
//  Created by Vladimir Solomenchuk on 27.01.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import "Controller.h"
#import "DownloadsController.h"
#import "PreferencesController.h"
#import "PreferencesController.h"
#include "TorrentViewController.h"
#include "Torrent.h"
#include "TorrentDelegate.h"
#include "TorrentTableView.h"
#include "ProcessesController.h"
#include <Growl/Growl.h>

@implementation Controller
+(void) initialize
{
	//Create dictionary
	NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];
	
	//Put defaults into dictionary
	[defaultValues setObject:[NSNumber numberWithInt:10]
					  forKey:NISpeedLimitUpload];

	[defaultValues setObject:[NSNumber numberWithInt:10]
					  forKey:NISpeedLimitDownload];

	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NITrashDownloadDescriptorsKey];

	
	//Register the dictionary of defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];

	//Growl needs it
	[GrowlApplicationBridge setGrowlDelegate:@""];
	
	if ([[ProcessesController sharedProcessesController] count]>0)
		[[DownloadsController sharedDownloadsController] startUpdates];
	
}

- (id)init
{
    if (self = [super init]) 
	{
		_defaults = [NSUserDefaults standardUserDefaults];
		_preferencesController = [[PreferencesController alloc] init];
    }
    return self;
}

-(void)checkSpeedLimit
{
	//check speed limit
	__block Controller *blockSelf = self;
	NumberResponseBlock response = [^(NSNumber* speed, NSString* error) {
		if (error == nil)
		{
			if ([speed intValue]>0)
				[blockSelf->_turtleButton setState: NSOnState];
			else 
				[blockSelf->_turtleButton setState: NSOffState];
		}
	} copy];
	[[DownloadsController sharedDownloadsController] getGlobalDownloadSpeedLimit:response];
	[response release];
}


- (void)awakeFromNib
{
	[self setupToolbar];

	[self checkSpeedLimit];
	
	//bottom bar for window
	//http://iloveco.de/bottom-bars-in-cocoa/
	[_window setContentBorderThickness:24.0 forEdge:NSMinYEdge];
	
	if ([[ProcessesController sharedProcessesController] count]==0)
	{
		[self showPreferencePanel:nil];
	}
	
}

-(IBAction)showPreferencePanel:(id)sender;
{
	[[DownloadsController sharedDownloadsController] stopUpdates];
	NSWindow * window = [_preferencesController window];
    if (![window isVisible])
        [window center];
	
    [window makeKeyAndOrderFront: nil];
}

-(IBAction)toggleTurtleSpeed:(id)sender
{
	__block Controller *blockSelf = self;
	VoidResponseBlock responseDownload = [^(NSString* error)
	{
		VoidResponseBlock responseUpload = [^(NSString* error)
		{
			[blockSelf checkSpeedLimit];
		}copy];
		int speedUpload = [_turtleButton state] == NSOnState?[_defaults integerForKey:NISpeedLimitUpload]*1024:0;
		[[DownloadsController sharedDownloadsController] setGlobalUploadSpeedLimit:speedUpload response:responseUpload];
		[responseUpload release];
	}copy];
	int speedDownload = [_turtleButton state] == NSOnState?[_defaults integerForKey:NISpeedLimitDownload]*1024:0;
	[[DownloadsController sharedDownloadsController] setGlobalDownloadSpeedLimit:speedDownload response:responseDownload];
	[responseDownload release];
}


-(IBAction)removeNoDeleteSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] erase:t.thash response:nil];
	[_downloadsView deselectAll: nil];
}
-(IBAction)stopSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] stop:t.thash response:nil];
}
-(IBAction)resumeSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] start:t.thash response:nil];
}

//opens window for selecting torrent
- (void) openShowSheet: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
	
    [panel setAllowsMultipleSelection: YES];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
	
    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects: @"org.bittorrent.torrent", @"torrent", nil]
				   modalForWindow: _window modalDelegate: self didEndSelector: @selector(openSheetClosed:returnCode:contextInfo:)
					  contextInfo: nil];
}

- (void) openSheetClosed: (NSOpenPanel *) panel returnCode: (NSInteger) code contextInfo: (NSNumber *) useOptions
{
    if (code == NSOKButton)
		[[DownloadsController sharedDownloadsController] add:[panel filenames]];
}

@end
