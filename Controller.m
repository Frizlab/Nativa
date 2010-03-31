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
#import "TorrentViewController.h"
#import "Torrent.h"
#import "TorrentTableView.h"
#import "ProcessesController.h"
#import <Growl/Growl.h>
#import "DragOverlayWindow.h"
#import "ToolbarControllerAdditions.h"
#import "QuickLookController.h"
#import "GroupsController.h"

@implementation Controller
+(void) initialize
{
	//Create dictionary
	NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];
	
	//Put defaults into dictionary
	[defaultValues setObject:[NSNumber numberWithInteger:10]
					  forKey:NISpeedLimitUpload];

	[defaultValues setObject:[NSNumber numberWithInteger:10]
					  forKey:NISpeedLimitDownload];

	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NITrashDownloadDescriptorsKey];

	[defaultValues setObject:[NSNumber numberWithInteger:3]
					  forKey:NIRefreshRateKey];

	[defaultValues setObject:[NSNumber numberWithInteger:300]
					  forKey:NIUpdateGlobalsRateKey];
	
	//Register the dictionary of defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];

	//Growl needs it
	[GrowlApplicationBridge setGrowlDelegate:@""];
}

- (id)init
{
    if (self = [super init]) 
	{
		_defaults = [NSUserDefaults standardUserDefaults];
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

	//for QuickLook functionality
	[_window makeFirstResponder:_downloadsView];
	
	//bottom bar for window
	//http://iloveco.de/bottom-bars-in-cocoa/
	[_window setContentBorderThickness:24.0 forEdge:NSMinYEdge];
	_overlayWindow = [[DragOverlayWindow alloc] initWithWindow: _window];
	
	if ([[ProcessesController sharedProcessesController] count]>0)
	{
		[_overlayWindow setImageAndMessage:[NSImage imageNamed: @"Loading.gif"] mainMessage:@"Connecting ..." message:nil];
		__block Controller *blockSelf = self;
		VoidResponseBlock response = [^(NSString* error){
			if (error)
				[blockSelf->_overlayWindow setImageAndMessage:[NSImage imageNamed: @"Error-large.png"] mainMessage:@"Error" message:error];
			else 
			{
				[self checkSpeedLimit];
				[blockSelf->_overlayWindow fadeOut];
			}
		}copy];
		[[DownloadsController sharedDownloadsController] startUpdates:response];
		[response release];
	}
}

-(IBAction)showPreferencePanel:(id)sender;
{
	[[PreferencesController sharedPreferencesController] openPreferences:NIPReferencesViewDefault];
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
		int speedUpload = [blockSelf->_turtleButton state] == NSOnState?[blockSelf->_defaults integerForKey:NISpeedLimitUpload]*1024:0;
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
		[[DownloadsController sharedDownloadsController] erase:t withData:NO response:nil];
	[_downloadsView deselectAll: nil];
}

-(IBAction)removeDeleteSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] erase:t withData:YES response:nil];
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

- (IBAction) toggleQuickLook:(id)sender
{
	[QuickLookController show];
}

- (IBAction) revealSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *torrent in torrents)
		[[DownloadsController sharedDownloadsController] reveal:torrent];
	
}

- (void) setGroup: (id) sender
{
	NSString *group = [[GroupsController groups] nameForIndex:[sender tag]];

	if (_menuTorrent == nil)
	{
		for (Torrent * torrent in [_downloadsView selectedTorrents])
		{
			[[DownloadsController sharedDownloadsController] setGroup:torrent group:group response:nil];
			[_downloadsView deselectAll: nil];
		}
	}
	else
	{
		[[DownloadsController sharedDownloadsController] setGroup:_menuTorrent group:group response:nil];
	}
}
- (void) showGroupMenuForTorrent:(Torrent *) torrent atLocation:(NSPoint) location
{
	_menuTorrent = [torrent retain];
	
	[_groupMenu popUpMenuPositioningItem: nil atLocation: location inView: _downloadsView];
	
	[_menuTorrent release];
	
	_menuTorrent = nil;
}
- (NSMenu *) contextRowMenu
{
	return _contextRowMenu;
}

#pragma mark -
#pragma mark NSMenuDelegate stuff

- (void) menuNeedsUpdate: (NSMenu *) menu
{
    if (menu == _groupMenu)
    {
        [menu removeAllItems];
		
        NSMenu * groupMenu;
		groupMenu = [[GroupsController groups] groupMenuWithTarget: self action: @selector(setGroup:) isSmall: NO];
        
        const NSInteger groupMenuCount = [groupMenu numberOfItems];
        for (NSInteger i = 0; i < groupMenuCount; i++)
        {
            NSMenuItem * item = [[groupMenu itemAtIndex: 0] retain];
            [groupMenu removeItemAtIndex: 0];
            [menu addItem: item];
            [item release];
        }
    }
    else;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem 
{
	SEL action = [menuItem action];
	
	BOOL canUseTable = [_window isKeyWindow] || [[menuItem menu] supermenu] != [NSApp mainMenu];
	
    if (action == @selector(toggleQuickLook:))
    {
        //text consistent with Finder
        NSString * title = [[QuickLookController sharedQuickLookController] isVisible] ?
		NSLocalizedString(@"Close Quick Look", "View menu -> Quick Look")
		:NSLocalizedString(@"Quick Look", "View menu -> Quick Look");
        [menuItem setTitle: title];
        
        return YES;
    }
	
	//enable pause item
    if (action == @selector(stopSelectedTorrents:))
    {
        if (!canUseTable)
            return NO;
		
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (torrent.active)
                return YES;
        return NO;
    }

	//enable pause item
    if (action == @selector(resumeSelectedTorrents:))
    {
        if (!canUseTable)
            return NO;
		
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (!torrent.active)
                return YES;
        return NO;
    }
	
	if (action == @selector(removeNoDeleteSelectedTorrents:) 
		|| action == @selector(removeDeleteSelectedTorrents:)
		|| action == @selector(revealSelectedTorrents:))
    {
        return canUseTable && [_downloadsView numberOfSelectedRows] > 0;
    }
	
	if (action == @selector(setGroup:))
    {
        BOOL checked = NO;
        
        NSInteger index = [menuItem tag];
		
		if (_menuTorrent == nil)
		{
			for (Torrent * torrent in [_downloadsView selectedTorrents])
			{
				
				NSInteger torrentGroupIndex = [[GroupsController groups] groupIndexForTorrent: torrent];
				if (index == torrentGroupIndex)
				{
					checked = YES;
					break;
				}
			}
		}
		else
		{
			NSInteger torrentGroupIndex = [[GroupsController groups] groupIndexForTorrent: _menuTorrent];
			if (index == torrentGroupIndex)
			{
				checked = YES;
			}
		}
        [menuItem setState: checked ? NSOnState : NSOffState];
		
        return canUseTable && (_menuTorrent != nil || [_downloadsView numberOfSelectedRows] > 0);
    }
	
	return YES;
}
@end
