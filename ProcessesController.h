//
//  ProcessesController.h
//  Nativa
//
//  Created by Vladimir Solomenchuk on 03.02.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TorrentDelegate.h"

@class ProcessDescriptor;

@interface ProcessesController : NSObject 
{
    NSMutableArray *_processesDescriptors;
	NSMutableArray *_processes;
}
+ (ProcessesController *)sharedProcessesController;


-(NSInteger) count;
-(ProcessDescriptor*) processDescriptorAtIndex:(NSInteger) index;
-(void)saveProcesses;
@end