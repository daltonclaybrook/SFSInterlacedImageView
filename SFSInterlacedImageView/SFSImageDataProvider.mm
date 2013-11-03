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

@interface SFSImageDataProvider () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *activeConnection;
@property (nonatomic, strong) SFSImageInterlacer *interlacer;
@property (nonatomic, strong) NSDate *lastFetchDate;
@property (nonatomic) BOOL finalImageBatched;

/****TEST****/
@property (nonatomic) long long bytesReceived;
@property (nonatomic) long long expectedContentLength;

@end

@implementation SFSImageDataProvider

#pragma mark - Initializers

- (instancetype)initWithImageURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        selfRef = self;
        _imageURL = url;
        _minimumImageFetchInterval = 0.7f;
        _lastFetchDate = [NSDate distantPast];
        _finalImageBatched = NO;
        _firstPassToGenerate = 1;
    }
    return self;
}

#pragma mark - Public

- (void)start
{
    NSAssert(_imageURL, @"Image URL must not be nil");
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.imageURL];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    _activeConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)cancel
{
    if (self.activeConnection)
    {
        [self.activeConnection cancel];
        self.activeConnection = nil;
    }
}

#pragma mark - Private

//- (void)completeLoading

#pragma mark - libpng C functions

SFSImageDataProvider *selfRef = nil;
int width, height;
int pixel_depth;

png_structp png_ptr;
png_infop   info_ptr;
png_bytepp row_pointers;

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
    row_pointers = (png_bytepp)malloc(sizeof(png_bytep) * info->height);
    for(size_t n=0;n<info->height;n++) {
        row_pointers[n] = (png_bytep)malloc(info->rowbytes);
    }
    
    png_set_interlace_handling(png_ptr);
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
    
    NSTimeInterval timeSinceLastFetch = [[NSDate date] timeIntervalSinceDate:selfRef.lastFetchDate];
    if (timeSinceLastFetch > selfRef.minimumImageFetchInterval && !selfRef.interlacer.generatingImage && pass > selfRef.firstPassToGenerate)
    {
        selfRef.lastFetchDate = [NSDate date];
        generate_interlaced_image(pass, NO);
    }
    
    /* where old_row is what was displayed for previously for the row. Note that the first pass (pass == 0, really) will completely cover the old row, so the rows do not have to be initialized. After the first pass (and only for interlaced images), you will have to pass the current row, and the function will combine the old row and the new row.  */
}


int file_end=0;
void end_callback(png_structp png_ptr, png_infop info) {
    /* This function is called after the whole image has been read, including any chunks after the image (up to and including the IEND). You will usually have the same info chunk as you had in the header, although some data may have been added to the comments and time fields.  Most people won’t do much here, perhaps setting a flag that marks the image as finished.  */
    printf("processing complete\n");
    file_end=1;
    
    if (!selfRef.interlacer.generatingImage)
    {
        generate_interlaced_image(6, YES);
        png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
        
        for(size_t n=0;n<height;n++) {
            free(row_pointers[n]);
        }
        free(row_pointers);
    }
    else
    {
        selfRef.finalImageBatched = YES;
    }
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

void generate_interlaced_image(int pass, bool final)
{
    NSMutableData *allData = [NSMutableData data];
    for (int i=0; i<height; i++)
    {
        NSData *rowData = [[NSData alloc] initWithBytes:row_pointers[i] length:width*pixel_depth/8];
        [allData appendData:rowData];
    }
    
    __typeof__(selfRef) __weak weakSelf = selfRef;
    
    [weakSelf.interlacer updateImageWithCurrentData:allData pass:pass completion:^(UIImage *image, NSError *error) {
        if ([weakSelf.delegate respondsToSelector:@selector(imageDataProvider:receivedImage:)])
        {
            [weakSelf.delegate imageDataProvider:weakSelf receivedImage:image];
            
            if (weakSelf.finalImageBatched)
            {
                weakSelf.finalImageBatched = NO;
                generate_interlaced_image(pass, YES);
                png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
                for(size_t n=0;n<height;n++) {
                    free(row_pointers[n]);
                }
                free(row_pointers);
                weakSelf.interlacer = nil;
            }
        }
        
        if (final && [weakSelf.delegate respondsToSelector:@selector(imageDataProviderCompletedLoading:)])
        {
            [weakSelf.delegate imageDataProviderCompletedLoading:weakSelf];
        }
    }];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.interlacer = nil;
    self.activeConnection = nil;
    png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
    
    if (row_pointers != NULL)
    {
        free(row_pointers);
    }
    
    if ([self.delegate respondsToSelector:@selector(imageDataProvider:failedWithError:)])
    {
        [self.delegate imageDataProvider:self failedWithError:error];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.bytesReceived = 0;
    self.expectedContentLength = response.expectedContentLength;
    initialize_png_reader();
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    int result = process_data((png_bytep)[data bytes], data.length);
    if (result == 1)
    {
        NSLog(@"error");
    }
    
    self.bytesReceived += data.length;
    CGFloat progress = MIN(((float)self.bytesReceived/(float)self.expectedContentLength), 1.0);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SFSImageDataProviderDataProgressNotification object:[NSNumber numberWithFloat:progress]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.activeConnection = nil;
}

@end
