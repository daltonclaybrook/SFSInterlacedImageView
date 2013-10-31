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
#import "pnginfo.h"

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
int width, height;
int pixel_depth;

png_structp png_ptr;
png_infop   info_ptr;
png_bytep * row_pointers;

/* This function is called (as set by png_set_progressive_read_fn() above) when enough data has been supplied so all of the header has been read.  */
void info_callback(png_structp png_ptr, png_infop info) {
    /* Do any setup here, including setting any of the transformations mentioned in the Reading PNG files section. For now, you _must_ call either png_start_read_image() or png_read_update_info() after all the transformations are set (even if you don’t set any). You may start getting rows before png_process_data() returns, so this is your last chance to prepare for that.  */
    
    printf("image height %u\n",info->height);
    printf("image width  %u\n",info->width );
    printf("pixel depth  %u\n",info->pixel_depth);
    
    width  = png_get_image_width(png_ptr, info);
    height = png_get_image_height(png_ptr, info);
    pixel_depth = info->pixel_depth;
    
    selfRef.interlacer = [[SFSImageInterlacer alloc] initWithSize:CGSizeMake(width, height) pixelDepth:pixel_depth];
    row_pointers = (png_bytep *)malloc(sizeof(png_bytep *) * info->height);
    for(size_t n=0;n<info->height;n++) {
        row_pointers[n] = (png_bytep)malloc(info->rowbytes);
    }
    
    png_start_read_image(png_ptr);
}

int get_pixel(char *row,int pixel_depth,int idx) {
    
    int pos  = pixel_depth*idx;
    
    int byte = pos/8;
    int bit  = pos-((pos/8)*8);
    
    int value = 0;
    for(int n=0;n<pixel_depth;n++) {
        value = value << 1;
        if(row[byte] & (1 << (8-bit))) value |= (value + 1);
        bit++;
        if(bit > 8) {bit=0; byte++;}
    }
    
    return value;
}

/* This function is called when each row of image data is complete */
void row_callback(png_structp png_ptr, png_bytep new_row, png_uint_32 row_num, int pass) {
    /* If the image is interlaced, and you turned on the interlace handler, this function will be called for every row in every pass. Some of these rows will not be changed from the previous pass. When the row is not changed, the new_row variable will be NULL. The rows and passes are called in order, so you don’t really need the row_num and pass, but I’m supplying them because it may make your life easier.  For the non-NULL rows of interlaced images, you must call png_progressive_combine_row() passing in the row and the old row. You can call this function for NULL rows (it will just return) and for non-interlaced images (it just does the memcpy for you) if it will make the code easier. Thus, you can just do this for all cases: */
    
    png_progressive_combine_row(png_ptr, row_pointers[row_num], new_row);
//    for(int n=0;n<width;n++) {
//        int pixel = get_pixel((char *)row_pointers[row_num], pixel_depth, n);
//        if(pixel == 0) printf("0"); else printf("1");
//    }
//    printf("\n");
    
    if (new_row != NULL && !selfRef.interlacer.generatingImage)
    {
        NSData *rowData = [[NSData alloc] initWithBytes:row_pointers[row_num] length:width*pixel_depth/8];
        [selfRef.interlacer updateImageWithRow:row_num data:rowData pass:pass completion:^(UIImage *image, NSError *error) {
            NSLog(@"received image");
        }];
    }
    
    /* where old_row is what was displayed for previously for the row. Note that the first pass (pass == 0, really) will completely cover the old row, so the rows do not have to be initialized. After the first pass (and only for interlaced images), you will have to pass the current row, and the function will combine the old row and the new row.  */
}


int file_end=0;
void end_callback(png_structp png_ptr, png_infop info) {
    /* This function is called after the whole image has been read, including any chunks after the image (up to and including the IEND). You will usually have the same info chunk as you had in the header, although some data may have been added to the comments and time fields.  Most people won’t do much here, perhaps setting a flag that marks the image as finished.  */
    printf("processing complete\n");
    file_end=1;
}

/* An example code fragment of how you would initialize the progressive reader in your application. */
int initialize_png_reader() {
    png_ptr = png_create_read_struct (PNG_LIBPNG_VER_STRING, (png_voidp)NULL,NULL,NULL);
    if(!png_ptr) return 1;
    info_ptr = png_create_info_struct(png_ptr);
    if(!info_ptr) {
        png_destroy_read_struct(&png_ptr, (png_infopp)NULL, (png_infopp)NULL);
        return 1;
    }
    if(setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
        return 1;
    }
    /* This one’s new. You can provide functions to be called when the header info is valid, when each row is completed, and when the image is finished. If you aren’t using all functions, you can specify NULL parameters. Even when all three functions are NULL, you need to call png_set_progressive_read_fn(). You can use any struct as the user_ptr (cast to a void pointer for the function call), and retrieve the pointer from inside the callbacks using the function png_get_progressive_ptr(png_ptr); which will return a void pointer, which you have to cast appropriately.  */
    
    png_set_interlace_handling(png_ptr);
    png_set_progressive_read_fn(png_ptr, (void *)NULL, info_callback, row_callback, end_callback);
    return 0;
}

/* A code fragment that you call as you receive blocks of data */
int process_data(png_bytep buffer, png_uint_32 length) {
    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
        return 1;
    }
    /* This one’s new also. Simply give it a chunk of data from the file stream (in order, of course). On machines with segmented memory models machines, don’t give it any more than 28 64K. The library seems to run fine with sizes of 4K. Although you can give it much less if necessary (I assume you can give it chunks of 1 byte, I haven’t tried less then 256 bytes yet). When this function returns, you may want to display any rows that were generated in the row callback if you don’t already do so there.  */
    png_process_data(png_ptr, info_ptr, buffer, length);
    return 0;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.interlacer = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_mutableData setLength:0];
    [_dataChunks removeAllObjects];
    [_rowDataArray removeAllObjects];
    self.dataIndex = 0;
    self.idatChunksRead = 0;
    self.passesComplete = 0;
    
    initialize_png_reader();
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
//    [_mutableData appendData:data];
    
    int result = process_data((png_bytep)[data bytes], data.length);
    if (result == 1)
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
    self.interlacer = nil;
}

@end
