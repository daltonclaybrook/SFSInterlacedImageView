//
//  SFSImageDataProvider.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Bottle Rocket, LLC. All rights reserved.
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

#pragma mark - libpng C functions

SFSImageDataProvider *selfRef = nil;
int width, height;
int pixel_depth;

png_structp png_ptr;
png_infop   info_ptr;
png_bytepp row_pointers;

void info_callback(png_structp png_ptr, png_infop info) {
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

void row_callback(png_structp png_ptr, png_bytep new_row, png_uint_32 row_num, int pass)
{
    png_progressive_combine_row(png_ptr, row_pointers[row_num], new_row);
    
    NSTimeInterval timeSinceLastFetch = [[NSDate date] timeIntervalSinceDate:selfRef.lastFetchDate];
    if (timeSinceLastFetch > selfRef.minimumImageFetchInterval && !selfRef.interlacer.generatingImage && pass > selfRef.firstPassToGenerate)
    {
        selfRef.lastFetchDate = [NSDate date];
        generate_interlaced_image(pass, NO);
    }
}


int file_end=0;
void end_callback(png_structp png_ptr, png_infop info)
{
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

int initialize_png_reader()
{
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
    
    png_set_progressive_read_fn(png_ptr, (void *)NULL, info_callback, row_callback, end_callback);
    return 0;
}

int process_data(png_bytep buffer, png_uint_32 length)
{
    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
        return 1;
    }
    
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
                destroyRowPointers();
                weakSelf.interlacer = nil;
            }
        }
        
        if (final && [weakSelf.delegate respondsToSelector:@selector(imageDataProviderCompletedLoading:)])
        {
            [weakSelf.delegate imageDataProviderCompletedLoading:weakSelf];
        }
    }];
}

void destroyRowPointers()
{
    if (row_pointers != NULL)
    {
        for (size_t n=0; n<height; n++)
        {
            if (row_pointers[n] != NULL)
            {
                free(row_pointers[n]);
            }
        }
        free(row_pointers);
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.interlacer = nil;
    self.activeConnection = nil;
    png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
    
    destroyRowPointers();
    
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
        [self cancel];
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
