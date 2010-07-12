/******************************************************************************
 * Nativa - MacOS X UI for rtorrent
 * http://www.aramzamzam.net
 *
 * Copyright Solomenchuk V. 2010.
 * Solomenchuk Vladimir <vovasty@aramzamzam.net>
 *
 * Licensed under the GPL, Version 3.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.gnu.org/licenses/gpl-3.0.html
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#import "ProcessPreferencesController.h"
#import "ProcessesController.h"
#import "SaveProgressController.h"

@interface ProcessPreferencesController(Private)

-(void)updateSelectedProcess;

- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info;

- (NSInteger) currentProcess;
@end

@implementation ProcessPreferencesController

@synthesize useSSHKeyLogin, useSSHV2, host, port, useSSH, sshHost, sshPort, sshLocalPort, sshUser, sshPassword, groupsField, sshCompressionLevel;

- (void) awakeFromNib
{
	pc = [ProcessesController sharedProcessesController];
	[self updateSelectedProcess];
}
//show folder doalog for downloads path
- (void) downloadsPathShow: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
	
    [panel setPrompt: NSLocalizedString(@"Select", "Preferences -> Open panel prompt")];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
	
    [panel beginSheetForDirectory: nil file: nil types: nil
				   modalForWindow: _window modalDelegate: self didEndSelector:
	 @selector(downloadsPathClosed:returnCode:contextInfo:) contextInfo: nil];
	
}

- (void) saveProcess: (id) sender
{
	[_window makeFirstResponder: nil];

	NSInteger index = [self currentProcess];
	
	[[SaveProgressController sharedSaveProgressController] open: _window 
														message:NSLocalizedString(@"Checking configuration...", "Preferences -> Save process")
														handler:^{[pc closeProcessForIndex:index];}];

	//test connection with only one reconnect
	int maxReconnects = ([pc maxReconnectsForIndex:index] == 0?10:[pc maxReconnectsForIndex:index]);

	[pc setMaxReconnects:0 forIndex:index];
    
    [pc setHost:host forIndex:index];
    
    [pc setPort:port forIndex:index];
    
    [pc setConnectionType:useSSH?@"SSH":@"Local" forIndex:index];
    
    [pc setSshHost:sshHost forIndex:index];
    
    [pc setSshPort:sshPort forIndex:index];
    
    [pc setSshLocalPort:sshLocalPort forIndex:index];
    
    [pc setSshUser:sshUser forIndex:index];
    
    [pc setSshPassword:sshPassword forIndex:index];

    [pc setSshUseKeyLogin:useSSHKeyLogin forIndex:index];
    
    [pc setGroupsField:groupsField forIndex:index];
    
    [pc setSshUseV2:useSSHV2 forIndex:index];
    
    [pc setSshCompressionLevel:sshCompressionLevel forIndex:index];

    [pc openProcessForIndex:index handler:^(NSString *error){
        [pc setMaxReconnects:maxReconnects forIndex:index];
        if (error != nil)
        {
			NSLog(@"error: %@", error);
			[[SaveProgressController sharedSaveProgressController] message: error];
			[[SaveProgressController sharedSaveProgressController] stop];
            [pc closeProcessForIndex:index];
            return;
        }
        [[self->pc processForIndex:index] list:^(NSArray *array, NSString* error){
            if (error != nil)
            {
                NSLog(@"error: %@", error);
                [[SaveProgressController sharedSaveProgressController] message: error];
                [[SaveProgressController sharedSaveProgressController] stop];
            }
            else
            {
                [[SaveProgressController sharedSaveProgressController] close:nil];
                
                [[ProcessesController sharedProcessesController] saveProcesses];
            }
            [pc closeProcessForIndex:index];
        }];
    }];
}

-(void) dealloc
{
    [self setHost:nil];
    [self setSshHost:nil];
    [self setSshUser:nil];
    [self setSshPassword:nil];
    [super dealloc];
}
@end

@implementation ProcessPreferencesController(Private)
-(void)updateSelectedProcess
{
    NSInteger index = [self currentProcess];
	
	[self setHost:[pc hostForIndex:index]];

	[self setPort:[pc portForIndex:index]==0?5000:[pc portForIndex:index]];
	
	[self setGroupsField:[pc groupsFieldForIndex:index]];
		
	[_downloadsPathPopUp removeItemAtIndex:0];
	if ([pc localDownloadsFolderForIndex:index] == nil)
		[_downloadsPathPopUp insertItemWithTitle:@"" atIndex:0];
	else
	{
		[_downloadsPathPopUp insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath: [pc localDownloadsFolderForIndex:index]] atIndex:0];
		
		NSString * path = [[pc localDownloadsFolderForIndex:index] stringByExpandingTildeInPath];
		NSImage * icon;
		//show a folder icon if the folder doesn't exist
		if ([[path pathExtension] isEqualToString: @""] && ![[NSFileManager defaultManager] fileExistsAtPath: path])
			icon = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode('fldr')];
		else
			icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
		
		[icon setSize: NSMakeSize(16.0, 16.0)];
		NSMenuItem* menuItem = [_downloadsPathPopUp itemAtIndex:0];
		[menuItem setImage:icon];
	}
	[_downloadsPathPopUp selectItemAtIndex: 0];
	
	[self setUseSSH:[[pc connectionTypeForIndex:index] isEqualToString:@"SSH"]];
		
	[self setSshHost:[pc sshHostForIndex:index]];
		
	[self setSshPort:[pc sshPortForIndex:index] == 0?22:[pc sshPortForIndex:index]];

	[self setSshUser: [pc sshUserForIndex:index]];
		
	[self setSshPassword: [pc sshPasswordForIndex:index]];
	
	[self setSshLocalPort: [pc sshLocalPortForIndex:index] == 0?5001:[pc sshLocalPortForIndex:index]];
	
	[self setUseSSHKeyLogin:[pc sshUseKeyLoginForIndex:index]];
    
    [self setSshCompressionLevel:[pc sshCompressionLevelForIndex:index]];
}

- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info
{
    if (code == NSOKButton)
    {
        NSInteger index = [self currentProcess];
		
		NSString * folder = [[openPanel filenames] objectAtIndex: 0];

		[pc setLocalDownloadsFolder:folder forIndex:index];
		
		[self updateSelectedProcess];
		
    }
}

- (NSInteger) currentProcess;
{
	if ([pc count]>0)
		return [pc indexForRow:0];
	else
		return [pc addProcess];
}
@end