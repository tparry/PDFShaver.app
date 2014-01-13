//
//  This is free and unencumbered software released into the public domain.
//
//  Anyone is free to copy, modify, publish, use, compile, sell, or
//  distribute this software, either in source code form or as a compiled
//  binary, for any purpose, commercial or non-commercial, and by any
//  means.
//
//  In jurisdictions that recognize copyright laws, the author or authors
//  of this software dedicate any and all copyright interest in the
//  software to the public domain. We make this dedication for the benefit
//  of the public at large and to the detriment of our heirs and
//  successors. We intend this dedication to be an overt act of
//  relinquishment in perpetuity of all present and future rights to this
//  software under copyright law.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  For more information, please refer to <http://unlicense.org/>
//

#import "PDFRedrawController.h"

#import "PDFRedrawFile.h"
#import "PDFDragDropView.h"
#import "PDFTableView.h"

typedef NS_ENUM(NSUInteger, PDFDragStatus)
{
	PDFDragStatusUp,
	PDFDragStatusDown
};

@interface PDFRedrawController () <NSTableViewDataSource, PDFDragDropViewDelegate, PDFRedrawFileDelegate, PDFTableViewEventDelegate>
{
	IBOutlet NSWindow* window;
	
	IBOutlet NSTableColumn* statusColumn;
	IBOutlet NSTableColumn* filenameColumn;
	IBOutlet NSTableColumn* filesizeColumn;
	IBOutlet NSTableColumn* savingsColumn;
	
	IBOutlet PDFTableView* redrawTableView;
	
	IBOutlet NSImageView* dragStatusImageView;
	
	IBOutlet NSNumberFormatter* decimalFormatter;
	IBOutlet NSNumberFormatter* percentageFormatter;
	
	NSMutableArray* redrawFiles;
	NSOperationQueue* redrawQueue;
}

- (PDFRedrawFile*) fileWithURL:(NSURL*) url;
- (void) reloadData;

@end

@implementation PDFRedrawController

- (id) init
{
	self = [super init];
	
	if(self != nil)
	{
		redrawFiles = [[NSMutableArray alloc] init];
		redrawQueue = [[NSOperationQueue alloc] init];
	}
	
	return self;
}

#pragma mark -
#pragma mark Super

- (void) setDragStatus:(PDFDragStatus) dragStatus
{
	[dragStatusImageView setAlphaValue:((dragStatus == PDFDragStatusUp) ? 0.8 : 1)];
}

- (void) awakeFromNib
{
	[super awakeFromNib];
	
	[window setContentBorderThickness:(redrawTableView.enclosingScrollView.frame.origin.y + 1) forEdge:NSMinYEdge];
	
	[redrawTableView.enclosingScrollView setHidden:YES];
	
	[self setDragStatus:PDFDragStatusUp];
}

#pragma mark -
#pragma mark Private

- (PDFRedrawFile*) fileWithURL:(NSURL*) url
{
	for(PDFRedrawFile* redrawFile in redrawFiles)
	{
		if([redrawFile.url isEqual:url])
			return redrawFile;
	}
	
	return nil;
}

- (void) reloadData
{
	[redrawTableView reloadData];
	[redrawTableView.enclosingScrollView setHidden:(redrawFiles.count <= 0)];
}

#pragma mark -
#pragma mark Window Events

- (IBAction) processClicked:(id) sender
{
	NSIndexSet* selectedIndexes = redrawTableView.selectedRowIndexes;
	
	if(selectedIndexes.count <= 0)
	{
		//	None selected, re-process all of them
		for(PDFRedrawFile* redrawFile in redrawFiles)
			[redrawFile process];
	}
	else
	{
		//	Only re-process the selected files
		[selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			PDFRedrawFile* redrawFile = [redrawFiles objectAtIndex:idx];
			[redrawFile process];
		}];
	}
}

#pragma mark -
#pragma mark PDFRedrawFile Delegate

- (void) redrawFileDidUpdate:(PDFRedrawFile*) sender
{
	[self reloadData];
}

#pragma mark -
#pragma mark PDFDragDropView Delegate

- (void) itemsEnteredDragDropView:(PDFDragDropView*) sender
{
	[self setDragStatus:PDFDragStatusDown];
}

- (void) itemsExitedDragDropView:(PDFDragDropView*) sender
{
	[self setDragStatus:PDFDragStatusUp];
}

- (void) dragDropView:(PDFDragDropView*) sender receivedFilepaths:(NSArray*) filepaths
{
	for(NSString* filepath in filepaths)
	{
		NSURL* url = [NSURL fileURLWithPath:filepath];
		
		PDFRedrawFile* file = [self fileWithURL:url];
		
		if(file == nil)
		{
			file = [[PDFRedrawFile alloc] initWithURL:url queue:redrawQueue];
			[file setDelegate:self];
			[redrawFiles addObject:file];
		}
		
		//	Start the redraw
		[file process];
	}
	
	[self reloadData];
}

#pragma mark -
#pragma mark PDFTableView EventDelegate

- (void) tableViewTriggeredDeleteEvent:(PDFTableView *)sender
{
	NSIndexSet* selectedIndexes = redrawTableView.selectedRowIndexes;
	
	if(selectedIndexes.count > 0)
	{
		[selectedIndexes enumerateIndexesWithOptions:(NSEnumerationReverse) usingBlock:^(NSUInteger idx, BOOL *stop) {
			[redrawFiles removeObjectAtIndex:idx];
		}];
		
		[self reloadData];
	}
}

#pragma mark -
#pragma mark NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return redrawFiles.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	PDFRedrawFile* redrawFile = [redrawFiles objectAtIndex:row];
	
	if(tableColumn == statusColumn)
	{
		switch(redrawFile.status)
		{
			case PDFRedrawStatusError:		return @"💔";
			case PDFRedrawStatusProcessing:	return @"💛";
			case PDFRedrawStatusIdle:		return @"💚";
		}
	}
	else if(tableColumn == filenameColumn)
	{
		return redrawFile.filename;
	}
	else if(tableColumn == filesizeColumn)
	{
		return [decimalFormatter stringFromNumber:@(redrawFile.filesize)];
	}
	else if(tableColumn == savingsColumn)
	{
		return [percentageFormatter stringFromNumber:@(redrawFile.savings)];
	}
	
	return nil;
}

@end
