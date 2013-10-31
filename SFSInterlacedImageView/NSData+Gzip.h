/**
 @file NSData+Gzip.h
 @brief Category on NSData that handles compression and decompression of gzip files
 @author Alan Duncan (www.cocoafactory.com)
 @version 1.0
 @date 2010-12-26
 @note This category was originally found at http://www.cocoadev.com/index.pl?NSDataCategory as the NSData+CocoaDevUsersAdditions and is slightly modified here.
 */

#ifndef __NSDATA_GZIP
#define __NSDATA_GZIP

#import <Foundation/Foundation.h>

/**	
 @category NSData(Gzip)
 @brief Compression/decompression of gzip
 @details A category on NSData that handles compression and decompression of gzip format
 
 @note Requires that you link against libz.dylib
 */
@interface NSData(Gzip)

- (NSData *)gzipInflate;
- (NSData *)gzipDeflate;

@end

#endif