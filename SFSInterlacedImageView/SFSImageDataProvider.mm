//
//  SFSImageDataProvider.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSImageDataProvider.h"
#import "SFSImageInterlacer.h"
#import "png.h"

typedef struct {
    uint32_t width;
    uint32_t height;
    uint8_t bitDepth;
    uint8_t colorType;
    uint8_t compressionMethod;
    uint8_t filterMethod;
    uint8_t interlaceMethod;
} IHDRChunk;

@interface SFSImageDataProvider () <NSURLConnectionDataDelegate> {
    NSMutableData *_mutableData;
    png_structp _png_ptr;
    png_infop _png_info;
}

@property (nonatomic, strong) NSURLConnection *activeConnection;
@property (nonatomic) BOOL interlacingConfirmed;

@property (nonatomic, assign) NSUInteger dataIndex;
@property (nonatomic, assign) IHDRChunk ihdrChunk;
@property (nonatomic, assign) NSUInteger idatChunksRead;
@property (nonatomic, assign) NSUInteger passesComplete;
@property (nonatomic, strong) NSMutableArray *dataChunks;
@property (nonatomic, strong) NSMutableData *chunkData;
@property (nonatomic, strong) NSMutableArray *rowDataArray;     // Contains a number of NSMutableData objects representing each row.
@property (nonatomic, strong) SFSImageInterlacer *interlacer;

@end

@implementation SFSImageDataProvider

@synthesize imageData = _mutableData;

#pragma mark - Initializers

- (instancetype)initWithImageURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        selfRef = self;
        _imageURL = url;
        _mutableData = [[NSMutableData alloc] init];
        _dataChunks = [[NSMutableArray alloc] init];
        _chunkData = [[NSMutableData alloc] init];
        _rowDataArray = [[NSMutableArray alloc] init];
        _interlacer = [[SFSImageInterlacer alloc] init];
    }
    return self;
}

#pragma mark - Public

- (void)start
{
    NSAssert(_imageURL, @"Image URL must not be nil");
    
    _interlacingConfirmed = NO;
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.imageURL];
    _activeConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)cancel
{
    [self.activeConnection cancel];
    self.activeConnection = nil;
}

#pragma mark - Private

- (NSError *)advanceDataIndexPastChunks
{
    if (self.imageData.length < 8) return nil;      // Haven't received the first 8 bytes, which is the signature
    if (self.dataIndex == 0 && ![self readSignature])
    {
        return [[NSError alloc] init];              // Change this.
    }
    
    NSError *error = nil;
    while ([self readNextChunkWithError:&error]);
    return error;
}

- (BOOL)readSignature
{
    uint8_t signature[] = { 137, 80, 78, 71, 13, 10, 26, 10 };  // PNG Signature
    for (int i=0; i<8; i++)
    {
        uint8_t byte;
        [self.imageData getBytes:&byte range:NSMakeRange(i, 1)];
        if (byte != signature[i])
        {
            return NO;
        }
    }
    
    self.dataIndex = 8;
    return YES;
}

- (BOOL)readNextChunkWithError:(NSError **)error
{
    uint32_t chunkLength;
    size_t lengthByteSize = sizeof(chunkLength);
    size_t chunkSignatureLength = 4;    // Chunk signatre, e.g. IHDR always has a length of 4
    size_t cyclicRedundancyCodeLenth = 4;
    if (self.imageData.length < self.dataIndex + lengthByteSize)
    {
        return NO;
    }
    
    [self.imageData getBytes:&chunkLength range:NSMakeRange(self.dataIndex, lengthByteSize)];
    chunkLength = CFSwapInt32HostToBig(chunkLength);
    if (self.imageData.length < self.dataIndex + lengthByteSize + chunkSignatureLength + chunkLength)
    {
        return NO;
    }
    self.dataIndex += lengthByteSize;
    
    uint32_t ihdrSignature = (73 << 24) | (72 << 16) | (68 << 8) | 82;
    uint32_t idatSignature = (73 << 24) | (68 << 16) | (65 << 8) | 84;
    uint32_t iendSignature = (73 << 24) | (69 << 16) | (78 << 8) | 68;
    
    uint32_t chunkSignature;
    [self.imageData getBytes:&chunkSignature range:NSMakeRange(self.dataIndex, chunkSignatureLength)];
    chunkSignature = CFSwapInt32HostToBig(chunkSignature);
    self.dataIndex += chunkSignatureLength;
    
    if (chunkSignature == ihdrSignature)
    {
        [self parseIHDRChunk];
        if (self.ihdrChunk.interlaceMethod == 0)
        {
            *error = [[NSError alloc] init];    // Change this
            return NO;
        }
    }
    else if (chunkSignature == idatSignature)   //This is the chunk that contains image data
    {
//        NSData *compressedData = [self.imageData subdataWithRange:NSMakeRange(self.dataIndex, chunkLength)];
//        NSData *uncompressedData = [compressedData zlibInflatePartial];
//        
//        for (int i=0; i<uncompressedData.length; i++)
//        {
//            uint8_t byte;
//            uint32_t size;
//            [uncompressedData getBytes:&byte range:NSMakeRange(i, 1)];
//            [uncompressedData getBytes:&size range:NSMakeRange(i, 4)];
//            size = CFSwapInt32HostToBig(size);
//            NSLog(@"%i, %c, %i", byte, byte, size);
//        }

        
        
        self.dataIndex += chunkLength;
        self.idatChunksRead++;
        NSUInteger passesComplete = [self evaluateCompletedAdam7Passes];
        if (self.passesComplete != passesComplete)
        {
            self.passesComplete = passesComplete;
            if ([self.delegate respondsToSelector:@selector(imageDataProvider:completedPass:)])
            {
                [self.delegate imageDataProvider:self completedPass:self.passesComplete];
            }
        }
    }
    else if (chunkSignature == iendSignature)
    {
        return NO;
    }
    else                                        // Simply skip this chunk
    {
        self.dataIndex += chunkLength;
    }
    
    self.dataIndex += cyclicRedundancyCodeLenth;
    return YES;
}

- (void)parseIHDRChunk
{
    [self.imageData getBytes:&_ihdrChunk.width range:NSMakeRange(self.dataIndex, sizeof(_ihdrChunk.width))];
    _ihdrChunk.width = CFSwapInt32HostToBig(_ihdrChunk.width);
    self.dataIndex += sizeof(_ihdrChunk.width);
    
    [self.imageData getBytes:&_ihdrChunk.height range:NSMakeRange(self.dataIndex, sizeof(_ihdrChunk.height))];
    _ihdrChunk.height = CFSwapInt32HostToBig(_ihdrChunk.height);
    self.dataIndex += sizeof(_ihdrChunk.height);
    
    [self.imageData getBytes:&_ihdrChunk.bitDepth range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.colorType range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.compressionMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.filterMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.interlaceMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
}

- (NSUInteger)evaluateCompletedAdam7Passes
{
    uint32_t pass1ChunkCount = ceil(self.ihdrChunk.width / 8.0f) * ceil(self.ihdrChunk.height / 8.0f);
    uint32_t pass2ChunkCount = ceil((self.ihdrChunk.width-4) / 8.0f) * ceil(self.ihdrChunk.height / 8.0f) + pass1ChunkCount;
    uint32_t pass3ChunkCount = ceil(self.ihdrChunk.width / 4.0f) * ceil((self.ihdrChunk.height-4) / 8.0f) + pass2ChunkCount;
    uint32_t pass4ChunkCount = ceil((self.ihdrChunk.width-2) / 4.0f) * ceil(self.ihdrChunk.height / 4.0f) + pass3ChunkCount;
    uint32_t pass5ChunkCount = ceil(self.ihdrChunk.width / 2.0f) * ceil((self.ihdrChunk.height-2) / 4.0f) + pass4ChunkCount;
    uint32_t pass6ChunkCount = ceil((self.ihdrChunk.width-1) / 2.0f) * ceil(self.ihdrChunk.height / 2.0f) + pass5ChunkCount;
    uint32_t pass7ChunkCount = self.ihdrChunk.width * self.ihdrChunk.height;
    
    if (self.idatChunksRead >= pass7ChunkCount) return 7;
    if (self.idatChunksRead >= pass6ChunkCount) return 6;
    if (self.idatChunksRead >= pass5ChunkCount) return 5;
    if (self.idatChunksRead >= pass4ChunkCount) return 4;
    if (self.idatChunksRead >= pass3ChunkCount) return 3;
    if (self.idatChunksRead >= pass2ChunkCount) return 2;
    if (self.idatChunksRead >= pass1ChunkCount) return 1;
    
    return 0;
}

#pragma mark - libpng C functions

SFSImageDataProvider *selfRef = nil;
//png_bytepp streamData = NULL;
//png_structp _png_ptr;
//png_infop _png_info;

int initialize_png_reader(png_structp *png_ptr, png_infop *info_ptr)
{
    /* Create and initialize the png_struct with the desired error handler
     * functions.  If you want to use the default stderr and longjump method,
     * you can supply NULL for the last three parameters.  We also check that
     * the library version is compatible in case we are using dynamically
     * linked libraries.
     */
    *png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    
    if (*png_ptr == NULL)
    {
        *info_ptr = NULL;
        return 0;
    }
    
    *info_ptr = png_create_info_struct(*png_ptr);
    
    if (*info_ptr == NULL)
    {
        png_destroy_read_struct(png_ptr, info_ptr, NULL);
        return 0;
    }
    
    if (setjmp(png_jmpbuf((*png_ptr))))
    {
        png_destroy_read_struct(png_ptr, info_ptr, NULL);
        return 0;
    }
    
    /* This one's new.  You will need to provide all three
     * function callbacks, even if you aren't using them all.
     * If you aren't using all functions, you can specify NULL
     * parameters.  Even when all three functions are NULL,
     * you need to call png_set_progressive_read_fn().
     * These functions shouldn't be dependent on global or
     * static variables if you are decoding several images
     * simultaneously.  You should store stream specific data
     * in a separate struct, given as the second parameter,
     * and retrieve the pointer from inside the callbacks using
     * the function png_get_progressive_ptr(png_ptr).
     */
    
//    png_bytepp streamData = NULL;
    
    png_set_interlace_handling(*png_ptr);
    png_set_progressive_read_fn(*png_ptr, (__bridge void *)selfRef.rowDataArray, info_callback, row_callback, end_callback);
    
    return 1;
}

int process_data(png_structp *png_ptr, png_infop *info_ptr,
             png_bytep buffer, png_uint_32 length)
{
    if (setjmp(png_jmpbuf((*png_ptr))))
    {
        /* Free the png_ptr and info_ptr memory on error */
        png_destroy_read_struct(png_ptr, info_ptr, NULL);
        return 0;
    }
    
    /* This one's new also.  Simply give it chunks of data as
     * they arrive from the data stream (in order, of course).
     * On segmented machines, don't give it any more than 64K.
     * The library seems to run fine with sizes of 4K, although
     * you can give it much less if necessary (I assume you can
     * give it chunks of 1 byte, but I haven't tried with less
     * than 256 bytes yet).  When this function returns, you may
     * want to display any rows that were generated in the row
     * callback, if you aren't already displaying them there.
     */
    png_process_data(*png_ptr, *info_ptr, buffer, length);
    return 1;
}

void info_callback(png_structp png_ptr, png_infop info)
{
    /* Do any setup here, including setting any of the transformations
     * mentioned in the Reading PNG files section.  For now, you _must_
     * call either png_start_read_image() or png_read_update_info()
     * after all the transformations are set (even if you don't set
     * any).  You may start getting rows before png_process_data()
     * returns, so this is your last chance to prepare for that.
     */
//    NSMutableArray *rows = [NSMutableArray array];
//    for (int i=0; i<png_get_image_height(png_ptr, info); i++)
//    {
//        [rows addObject:[NSMutableData data]];
//    }
//    selfRef.rowDataArray = [[NSArray alloc] initWithArray:rows];
    
    
//    int row;
    
//    png_bytep row_pointers[height];
//    png_bytepp streamData = (png_bytepp)png_get_progressive_ptr(png_ptr);
    NSMutableArray *rowDataArray = (__bridge NSMutableArray *)png_get_progressive_ptr(png_ptr);
    png_uint_32 height = png_get_image_height(png_ptr, info);
    for (int i=0; i<height; i++)
    {
        png_bytep row = NULL;
        [rowDataArray addObject:[NSValue valueWithPointer:row]];
    }
    
    /* Clear the pointer array */
//    for (row = 0; row < height; row++)
//        streamData[row] = NULL;
    
//    for (row = 0; row < height; row++)
//        streamData[row] = (png_bytep)png_malloc(png_ptr, png_get_rowbytes(png_ptr, info));
//
    png_start_read_image(png_ptr);
}

void row_callback(png_structp png_ptr, png_bytep new_row,
             png_uint_32 row_num, int pass)
{
    /*
     * This function is called for every row in the image.  If the
     * image is interlaced, and you turned on the interlace handler,
     * this function will be called for every row in every pass.
     *
     * In this function you will receive a pointer to new row data from
     * libpng called new_row that is to replace a corresponding row (of
     * the same data format) in a buffer allocated by your application.
     *
     * The new row data pointer "new_row" may be NULL, indicating there is
     * no new data to be replaced (in cases of interlace loading).
     *
     * If new_row is not NULL then you need to call
     * png_progressive_combine_row() to replace the corresponding row as
     * shown below:
     */
    
    /* Get pointer to corresponding row in our
     * PNG read buffer.
     */
//    NSMutableData *rowData = [selfRef.rowDataArray objectAtIndex:row_num];
    NSMutableArray *rowDataArray = (__bridge NSMutableArray *)png_get_progressive_ptr(png_ptr);
    NSValue *rowValue = [rowDataArray objectAtIndex:row_num];
//    NSMutableData *rowData = [rowDataArray objectAtIndex:row_num];
    png_bytep old_row = (png_bytep)[rowValue pointerValue];

//    png_bytep old_row = (png_bytep)[rowData bytes];
    
//    if (new_row != NULL)
//        [rowData replaceBytesInRange:NSMakeRange(0, rowData.length) withBytes:(void *)new_row];
    
#ifdef PNG_READ_INTERLACING_SUPPORTED
    /* If both rows are allocated then copy the new row
     * data to the corresponding row data.
     */
    if ((old_row != NULL) && (new_row != NULL))
    {
        png_progressive_combine_row(png_ptr, old_row, new_row);
    }
    else if (new_row != NULL)
    {
        [rowDataArray replaceObjectAtIndex:row_num withObject:[NSValue valueWithPointer:new_row]];
    }
//    if (new_row != NULL)
//        png_progressive_combine_row(png_ptr, old_row, new_row);
//    if (old_row != NULL)
//    {
//        if (new_row != NULL)
//        {
//            png_progressive_combine_row(png_ptr, old_row, new_row);
//        }
////        png_free(png_ptr, old_row);
//    }
    /*
     * The rows and passes are called in order, so you don't really
     * need the row_num and pass, but I'm supplying them because it
     * may make your life easier.
     *
     * For the non-NULL rows of interlaced images, you must call
     * png_progressive_combine_row() passing in the new row and the
     * old row, as demonstrated above.  You can call this function for
     * NULL rows (it will just return) and for non-interlaced images
     * (it just does the memcpy for you) if it will make the code
     * easier.  Thus, you can just do this for all cases:
     */
    
//    png_progressive_combine_row(png_ptr, old_row, new_row);
    
    /* where old_row is what was displayed for previous rows.  Note
     * that the first pass (pass == 0 really) will completely cover
     * the old row, so the rows do not have to be initialized.  After
     * the first pass (and only for interlaced images), you will have
     * to pass the current row as new_row, and the function will combine
     * the old row and the new row.
     */
#endif /* PNG_READ_INTERLACING_SUPPORTED */
}

void end_callback(png_structp png_ptr, png_infop info)
{
    /* This function is called when the whole image has been read,
     * including any chunks after the image (up to and including
     * the IEND).  You will usually have the same info chunk as you
     * had in the header, although some data may have been added
     * to the comments and time fields.
     *
     * Most people won't do much here, perhaps setting a flag that
     * marks the image as finished.
     */
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_mutableData setLength:0];
    [_dataChunks removeAllObjects];
    [_rowDataArray removeAllObjects];
    self.dataIndex = 0;
    self.idatChunksRead = 0;
    self.passesComplete = 0;
    
    initialize_png_reader(&_png_ptr, &_png_info);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_mutableData appendData:data];
    
    
    
    int result = process_data(&_png_ptr, &_png_info, (png_bytep)[data bytes], [data length]);
    if (result == 0)
    {
        NSLog(@"error");
    }
    
//    NSError *error = [self advanceDataIndexPastChunks];
//    if (error)
//    {
//        [self.activeConnection cancel];
//        if ([self.delegate respondsToSelector:@selector(imageDataProvider:failedWithError:)])
//        {
//            [self.delegate imageDataProvider:self failedWithError:error];
//        }
//    }
    
//    for (int i=0; i<data.length; i++)
//    {
//        uint8_t byte;
//        uint32_t size;
//        [data getBytes:&byte range:NSMakeRange(i, 1)];
//        [data getBytes:&size range:NSMakeRange(i, 4)];
//        size = CFSwapInt32HostToBig(size);
//        NSLog(@"%i, %c, %i", byte, byte, size);
//    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    
}

@end
