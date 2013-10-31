/**
 @file NSData+Zlib.h
 @brief Category on NSData that handles compression and decompression of zlib files
 @author Alan Duncan (www.cocoafactory.com)
 @version 1.0
 @date 2010-12-26
 @note This category was originally found at http://www.cocoadev.com/index.pl?NSDataCategory as the NSData+CocoaDevUsersAdditions and is slightly modified here.
 */

#ifndef __NSDATA_ZLIB
#define __NSDATA_ZLIB

#import <Foundation/Foundation.h>

/**	
 @category NSData(Zlib)
 @brief Compression/decompression of zlib
 @details A category on NSData that handles compression and decompression of zlib format
 
 @note Requires that you link against libz.dylib
 */
@interface NSData(Zlib)

- (NSData *)zlibInflate;
- (NSData *)zlibDeflate;

- (NSData *)zlibInflatePartial;

@end

#endif