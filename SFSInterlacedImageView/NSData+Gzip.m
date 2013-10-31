/**
 @file NSData+Gzip.m
 @brief Category on NSData that handles compression and decompression of gzip files
 @author Alan Duncan (www.cocoafactory.com)
 @version 1.0
 @date 2010-12-26
 @note This category was originally found at http://www.cocoadev.com/index.pl?NSDataCategory as the NSData+CocoaDevUsersAdditions and is slightly modified here.
 */


#import "NSData+Gzip.h"
#import "zlib.h"

@implementation NSData(Gzip)

- (NSData *)gzipInflate
{
	if ([self length] == 0) return self;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
	unsigned full_length = [self length];
	unsigned half_length = [self length] / 2;
#else
    unsigned full_length = (unsigned)[self length];
	unsigned half_length = (unsigned)[self length] / 2;
#endif
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
    strm.avail_in = [self length];
#else
    strm.avail_in = (int)[self length];
#endif
	
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
		strm.avail_out = [decompressed length] - strm.total_out;
#else
       strm.avail_out = (int)([decompressed length] - strm.total_out); 
#endif
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	}
	else return nil;
}

- (NSData *)gzipDeflate
{
	if ([self length] == 0) return self;
	
	z_stream strm;
	
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[self bytes];
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
	strm.avail_in = [self length];
#else
    strm.avail_in = (int)[self length];
#endif
	
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
	
	if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = [compressed mutableBytes] + strm.total_out;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
        strm.avail_out = [compressed length] - strm.total_out;
#else
        strm.avail_out = (int)([compressed length] - strm.total_out);
#endif
		
		
		deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return [NSData dataWithData:compressed];
}

@end
