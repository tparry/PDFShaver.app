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

#import "PDFRedrawOperation.h"

#import "PDFRedrawPage.h"

@interface PDFRedrawOperation ()

@end

@implementation PDFRedrawOperation

@synthesize url;
@synthesize delegate;

- (id) initWithURL:(NSURL*) _url
{
	self = [super init];
	
	if(self != nil)
	{
		url = [_url copy];
	}
	
	return self;
}

#pragma mark -
#pragma mark Super

- (void) main
{
	[super main];
	
	if(self.isCancelled)
		return;
	
	NSData* data = nil;
	
	if(url != nil)
	{
		CGPDFDocumentRef oldDocument = CGPDFDocumentCreateWithURL((CFURLRef)url);
		
		if(oldDocument != nil &&
		   !CGPDFDocumentIsEncrypted(oldDocument) &&
		   CGPDFDocumentAllowsPrinting(oldDocument))
		{
			PDFDocument* newDocument = [[PDFDocument alloc] init];
			
			const size_t numberOfPages = CGPDFDocumentGetNumberOfPages(oldDocument);
			
			//	Mark each page for redraw
			for(size_t currentPage = 1; currentPage <= numberOfPages; currentPage++)
			{
				CGPDFPageRef oldPage = CGPDFDocumentGetPage(oldDocument, currentPage);
				
				PDFRedrawPage* newPage = [[PDFRedrawPage alloc] init];
				[newPage setRedrawPage:oldPage];
				[newDocument insertPage:newPage atIndex:(currentPage - 1)];
			}
			
			CGPDFDocumentRelease(oldDocument);
			oldDocument = nil;
			
			data = newDocument.dataRepresentation;
		}
	}
	
	//	We're done, tell the delegate
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if(!self.isCancelled)
		{
			if(data.length <= 0)
				[delegate redrawOperationFailed:self];
			else
				[delegate redrawOperation:self finishedWithData:data];
		}
		
	});
}

@end
