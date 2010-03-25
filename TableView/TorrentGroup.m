/******************************************************************************
 * $Id: TorrentGroup.m 9844 2010-01-01 21:12:04Z livings124 $
 * 
 * Copyright (c) 2008-2010 Transmission authors and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *****************************************************************************/

#import "TorrentGroup.h"
#import "Torrent.h"

#define ICON_WIDTH 16.0
#define ICON_WIDTH_SMALL 12.0

@implementation TorrentGroup

@synthesize name, color;

- (id) initWithGroup: (NSInteger) group
{
    if ((self = [super init]))
    {
        fGroup = group;
        fTorrents = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [fTorrents release];
	[name release];
    [super dealloc];
}

- (NSInteger) groupIndex
{
    return fGroup;
}

- (NSMutableArray *) torrents
{
    return fTorrents;
}

- (CGFloat) ratio
{
    uint64_t uploaded = 0, downloaded = 0;
    for (Torrent * torrent in fTorrents)
    {
        uploaded += torrent.uploadRate;
        downloaded += torrent.downloadRate;
    }
	double ratio;
	if( downloaded )
        ratio = uploaded / downloaded;
    else if( uploaded )
        ratio = 0;
    else
        ratio = 0;
	
    return ratio;
	
	
    return 0;//tr_getRatio(uploaded, downloaded);
}

- (CGFloat) uploadRate
{
    CGFloat rate = 0.0;
    for (Torrent * torrent in fTorrents)
        rate += torrent.speedUpload;
    
    return rate;
}

- (CGFloat) downloadRate
{
    CGFloat rate = 0.0;
    for (Torrent * torrent in fTorrents)
        rate += torrent.speedDownload;
    
    return rate;
}

- (NSImage *) icon
{
	if (icon == nil)
    {
		NSRect rect = NSMakeRect(0.0, 0.0, ICON_WIDTH, ICON_WIDTH);
    
		NSBezierPath * bp = [NSBezierPath bezierPathWithRoundedRect: rect xRadius: 3.0 yRadius: 3.0];
		icon = [[NSImage alloc] initWithSize: rect.size];
    
		[icon lockFocus];
    
		//border
		NSGradient * gradient = [[NSGradient alloc] initWithStartingColor: [color blendedColorWithFraction: 0.45 ofColor:
																		[NSColor whiteColor]] endingColor: color];
		[gradient drawInBezierPath: bp angle: 270.0];
		[gradient release];
    
		//inside
		bp = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(rect, 1.0, 1.0) xRadius: 3.0 yRadius: 3.0];
		gradient = [[NSGradient alloc] initWithStartingColor: [color blendedColorWithFraction: 0.75 ofColor: [NSColor whiteColor]]
											 endingColor: [color blendedColorWithFraction: 0.2 ofColor: [NSColor whiteColor]]];
		[gradient drawInBezierPath: bp angle: 270.0];
		[gradient release];
    
		[icon unlockFocus];
    }
    return icon;
}

@end
