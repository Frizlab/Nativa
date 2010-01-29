//
//  ToolbarController.m
//  Nativa
//
//  Created by Vladimir Solomenchuk on 29.01.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import "ToolbarControllerAdditions.h"
#import "ButtonToolbarItem.h"
#import "GroupToolbarItem.h"
#import "ToolbarSegmentedCell.h"
#import "Torrent.h"

#define TOOLBAR_REMOVE                  @"Toolbar Remove"
#define TOOLBAR_PAUSE_RESUME_SELECTED   @"Toolbar Pause / Resume Selected"
#define TOOLBAR_PAUSE_SELECTED          @"Toolbar Pause Selected"
#define TOOLBAR_RESUME_SELECTED         @"Toolbar Resume Selected"

typedef enum
{
    TOOLBAR_PAUSE_TAG = 0,
    TOOLBAR_RESUME_TAG = 1
} toolbarGroupTag;

@implementation Controller(ToolbarControllerAdditions)
- (void)setupToolbar
{
    NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier: @"NIMainToolbar"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [_window setToolbar: toolbar];
    [toolbar release];	
}

- (ButtonToolbarItem *) standardToolbarButtonWithIdentifier: (NSString *) ident
{
    ButtonToolbarItem * item = [[ButtonToolbarItem alloc] initWithItemIdentifier: ident];
    
    NSButton * button = [[NSButton alloc] initWithFrame: NSZeroRect];
    [button setBezelStyle: NSTexturedRoundedBezelStyle];
    [button setStringValue: @""];
    
    [item setView: button];
    [button release];
    
    const NSSize buttonSize = NSMakeSize(36.0, 25.0);
    [item setMinSize: buttonSize];
    [item setMaxSize: buttonSize];
    
    return [item autorelease];
}

#pragma mark Responders
-(IBAction)removeNoDelete:(id)sender
{}
-(IBAction)selectedToolbarClicked:(id)sender
{
    NSInteger tagValue = [sender isKindOfClass: [NSSegmentedControl class]]
	? [(NSSegmentedCell *)[sender cell] tagForSegment: [sender selectedSegment]] : [sender tag];
    switch (tagValue)
    {
        case TOOLBAR_PAUSE_TAG:
            [self stopSelectedTorrents: sender];
            break;
        case TOOLBAR_RESUME_TAG:
            [self resumeSelectedTorrents: sender];
            break;
    }
}
#pragma mark NSToolbarDelegate

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects:
            TOOLBAR_REMOVE,
            TOOLBAR_PAUSE_RESUME_SELECTED,
            NSToolbarSeparatorItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            NSToolbarCustomizeToolbarItemIdentifier, nil];
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects:
            TOOLBAR_REMOVE, NSToolbarSeparatorItemIdentifier,
            TOOLBAR_PAUSE_RESUME_SELECTED, nil];
}



- (NSToolbarItem *) toolbar: (NSToolbar *) toolbar itemForItemIdentifier: (NSString *) ident willBeInsertedIntoToolbar: (BOOL) flag
{
   if ([ident isEqualToString: TOOLBAR_REMOVE])
    {
        ButtonToolbarItem * item = [self standardToolbarButtonWithIdentifier: ident];
        
        [item setLabel: NSLocalizedString(@"Remove", "Remove toolbar item -> label")];
        [item setPaletteLabel: NSLocalizedString(@"Remove Selected", "Remove toolbar item -> palette label")];
        [item setToolTip: NSLocalizedString(@"Remove selected transfers", "Remove toolbar item -> tooltip")];
        [item setImage: [NSImage imageNamed: @"ToolbarRemoveTemplate.png"]];
        [item setTarget: self];
        [item setAction: @selector(removeNoDeleteSelectedTorrents:)];
        
        return item;
    }
    else if ([ident isEqualToString: TOOLBAR_PAUSE_RESUME_SELECTED])
    {
        GroupToolbarItem * groupItem = [[GroupToolbarItem alloc] initWithItemIdentifier: ident];
        
        NSSegmentedControl * segmentedControl = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect];
        [segmentedControl setCell: [[[ToolbarSegmentedCell alloc] init] autorelease]];
        [groupItem setView: segmentedControl];
        NSSegmentedCell * segmentedCell = (NSSegmentedCell *)[segmentedControl cell];
        
        [segmentedControl setSegmentCount: 2];
        [segmentedCell setTrackingMode: NSSegmentSwitchTrackingMomentary];
        
        const NSSize groupSize = NSMakeSize(72.0, 25.0);
        [groupItem setMinSize: groupSize];
        [groupItem setMaxSize: groupSize];
        
        [groupItem setLabel: NSLocalizedString(@"Apply Selected", "Selected toolbar item -> label")];
        [groupItem setPaletteLabel: NSLocalizedString(@"Pause / Resume Selected", "Selected toolbar item -> palette label")];
        [groupItem setTarget: self];
        [groupItem setAction: @selector(selectedToolbarClicked:)];
        
        [groupItem setIdentifiers: [NSArray arrayWithObjects: TOOLBAR_PAUSE_SELECTED, TOOLBAR_RESUME_SELECTED, nil]];
        
        [segmentedCell setTag: TOOLBAR_PAUSE_TAG forSegment: TOOLBAR_PAUSE_TAG];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarPauseSelectedTemplate.png"] forSegment: TOOLBAR_PAUSE_TAG];
        [segmentedCell setToolTip: NSLocalizedString(@"Pause selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: TOOLBAR_PAUSE_TAG];
        
        [segmentedCell setTag: TOOLBAR_RESUME_TAG forSegment: TOOLBAR_RESUME_TAG];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarResumeSelectedTemplate.png"] forSegment: TOOLBAR_RESUME_TAG];
        [segmentedCell setToolTip: NSLocalizedString(@"Resume selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: TOOLBAR_RESUME_TAG];
        
        [groupItem createMenu: [NSArray arrayWithObjects: NSLocalizedString(@"Pause Selected", "Selected toolbar item -> label"),
								NSLocalizedString(@"Resume Selected", "Selected toolbar item -> label"), nil]];
        
        [segmentedControl release];
        return [groupItem autorelease];
    }
    else
        return nil;
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{
    NSString * ident = [toolbarItem itemIdentifier];
    
    //enable remove item
    if ([ident isEqualToString: TOOLBAR_REMOVE])
        return [_downloadsView numberOfSelectedRows] > 0;
	
    //enable pause item
    if ([ident isEqualToString: TOOLBAR_PAUSE_SELECTED])
    {
        for (Torrent * torrent in [self selectedTorrents])
            if (torrent.state == seeding || torrent.state == leeching)
                return YES;
        return NO;
    }
    
    //enable resume item
    if ([ident isEqualToString: TOOLBAR_RESUME_SELECTED])
    {
        for (Torrent * torrent in [self selectedTorrents])
            if (torrent.state == stopped)
                return YES;
        return NO;
    }
    
    return YES;
}

@end