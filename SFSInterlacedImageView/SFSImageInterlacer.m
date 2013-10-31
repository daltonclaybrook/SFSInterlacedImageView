//
//  SFSImageInterlacer.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSImageInterlacer.h"

//static int starting_row[7]  = { 0, 0, 4, 0, 2, 0, 1 };
//static int starting_col[7]  = { 0, 4, 0, 2, 0, 1, 0 };
//static int row_increment[7] = { 8, 8, 8, 4, 4, 2, 2 };
static int col_increment[7] = { 8, 8, 4, 4, 2, 2, 1 };
static int block_height[7]  = { 8, 8, 4, 4, 2, 2, 1 };
static int block_width[7]   = { 8, 4, 4, 2, 2, 1, 1 };

static NSUInteger bytesPerPixel = 4;     // Hardcoded to 4: R G B A

@interface SFSImageInterlacer ()
{
    char * _imageDataBuffer;
}

@property (nonatomic) CGSize imageSize;
@property (nonatomic) NSUInteger pixelDepth;
@property (nonatomic, strong) UIImage *currentImage;

@end

@implementation SFSImageInterlacer

- (instancetype)initWithSize:(CGSize)size pixelDepth:(NSUInteger)depth
{
    self = [super init];
    if (self)
    {
        _generatingImage = NO;
        _imageSize = size;
        _pixelDepth = depth;
        _imageDataBuffer = (char *)malloc(size.width*size.height*bytesPerPixel);
    }
    return self;
}

- (void)dealloc
{
    free(_imageDataBuffer);
}

- (void)updateImageWithRow:(NSUInteger)row data:(NSData *)rowData pass:(NSUInteger)pass completion:(SFSImageInterlacerCompletionBlock)completion
{
    self.generatingImage = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        [self updateImageWithRow:row data:rowData pass:pass];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.generatingImage = NO;
            if (completion)
                completion(self.currentImage, nil);     // Currently not handling errors.
        });
    });
}

#pragma mark - Private

- (void)updateImageWithRow:(NSUInteger)row data:(NSData *)rowData pass:(NSUInteger)pass
{
    NSUInteger xIncrement = col_increment[pass];
    NSUInteger currentBytesPerPixel = self.pixelDepth/8;
    BOOL hasAlpha = (currentBytesPerPixel == 4);
    
    for (int x=0; x<self.imageSize.width; x++)
    {
        NSUInteger xOffset = x*currentBytesPerPixel;
        uint8_t red, green, blue;
        uint8_t alpha = 255;
        
        [rowData getBytes:&red range:NSMakeRange(xOffset, 1)];
        [rowData getBytes:&green range:NSMakeRange(xOffset+1, 1)];
        [rowData getBytes:&blue range:NSMakeRange(xOffset+2, 1)];
        if (hasAlpha) [rowData getBytes:&alpha range:NSMakeRange(xOffset+3, 1)];
        
        [self setRed:red green:green blue:blue alpha:alpha atPoint:CGPointMake(x * xIncrement, row) adam7Pass:pass];
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(
                                                       _imageDataBuffer,
                                                       self.imageSize.width,
                                                       self.imageSize.height,
                                                       8, // bitsPerComponent
                                                       bytesPerPixel*self.imageSize.width, // bytesPerRow
                                                       colorSpace,
                                                       (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CFRelease(colorSpace);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    self.currentImage = [[UIImage alloc] initWithCGImage:cgImage];
    
    CFRelease(cgImage);
    CFRelease(bitmapContext);
}

- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha atPoint:(CGPoint)point adam7Pass:(NSUInteger)pass
{
    CGSize blockSize = CGSizeMake(block_width[pass], block_height[pass]);
    for (int y=point.y; y<point.y+blockSize.height; y++)
    {
        for (int x=point.x; x<point.x+blockSize.height; x++)
        {
            if ((x >= self.imageSize.width) || (y >= self.imageSize.height))
            {
                break;
            }
            
            NSUInteger offset = (y*self.imageSize.width*bytesPerPixel) + (x*bytesPerPixel);
            _imageDataBuffer[offset] = red;
            _imageDataBuffer[offset+1] = green;
            _imageDataBuffer[offset+2] = blue;
            _imageDataBuffer[offset+3] = alpha;
        }
    }
}

@end
