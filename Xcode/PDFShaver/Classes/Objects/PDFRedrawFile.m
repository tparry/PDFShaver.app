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

#import "PDFRedrawFile.h"

#import "PDFRedrawOperation.h"

@interface PDFRedrawFile () <PDFRedrawOperationDelegate>
{
	PDFRedrawOperation* currentOperation;
}

@end

@implementation PDFRedrawFile

@synthesize url;
@synthesize queue;
@synthesize delegate;

@synthesize status;
@synthesize filename;
@synthesize filesize;
@synthesize savings;

- (id) initWithURL:(NSURL*) _url queue:(NSOperationQueue*) _queue
{
	self = [super init];
	
	if(self != nil)
	{
		url = [_url copy];
		queue = _queue;
		
		status = PDFRedrawStatusIdle;
		filename = [url.path.lastPathComponent copy];
		
		NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
		
		//	File did not exist, or another error
		if(attributes == nil)
		{
			status = PDFRedrawStatusError;
		}
		else
		{
			filesize = [[attributes valueForKey:NSFileSize] unsignedIntegerValue];
		}
	}
	
	return self;
}

#pragma mark -
#pragma mark Self

- (void) process
{
	if(currentOperation == nil && queue != nil)
	{
		currentOperation = [[PDFRedrawOperation alloc] initWithURL:url];
		[currentOperation setDelegate:self];
		
		status = PDFRedrawStatusProcessing;
		
		[delegate redrawFileDidUpdate:self];
		
		[queue addOperation:currentOperation];
	}
}

#pragma mark -
#pragma mark PDFRedrawOperation Delegate

- (void) redrawOperation:(PDFRedrawOperation*) sender finishedWithData:(NSData*) data
{
	if(sender == currentOperation)
	{
		currentOperation = nil;
		
		status = PDFRedrawStatusIdle;
		
		const NSUInteger oldFileSize = filesize;
		const NSUInteger newFileSize = data.length;
		
		const BOOL newIsSmaller = (newFileSize < oldFileSize);
		
		//	We only want the smaller one
		if(newIsSmaller)
		{
			NSString* urlpath = url.path;
			NSString* toTrashFolderpath = urlpath.stringByDeletingLastPathComponent;
			NSString* toTrashFilename = urlpath.lastPathComponent;
			
			//	Trash the old
			const BOOL didTrashFile = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
																				   source:toTrashFolderpath
																			  destination:@""
																					files:@[toTrashFilename]
																					  tag:0];
			//	Write the new
			if(didTrashFile)
			{
				const BOOL didWriteFile = [data writeToURL:url atomically:YES];
				
				if(didWriteFile)
				{
					const NSUInteger difference = oldFileSize - newFileSize;
					filesize = newFileSize;
					savings = ((double)difference / (double)oldFileSize);
				}
				else
				{
					status = PDFRedrawStatusError;
				}
			}
			else
			{
				status = PDFRedrawStatusError;
			}
		}
		else
		{
			savings = 0;
		}
		
		[delegate redrawFileDidUpdate:self];
	}
}

- (void) redrawOperationFailed:(PDFRedrawOperation*) sender
{
	if(sender == currentOperation)
	{
		currentOperation = nil;
		
		status = PDFRedrawStatusError;
		
		[delegate redrawFileDidUpdate:self];
	}
}

#pragma mark -
#pragma mark Cleanup

- (void) dealloc
{
	[currentOperation cancel];
}

@end
