//
//  SFSImageInterlacer.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSImageInterlacer.h"

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
    }
    return self;
}

- (void)updateImageWithCurrentData:(NSData *)data pass:(NSUInteger)pass completion:(SFSImageInterlacerCompletionBlock)completion
{
    self.generatingImage = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        UIImage *image = [self updateImageWithCurrentData:data pass:pass];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.generatingImage = NO;
            if (completion)
                completion(image, nil);     // Currently not handling errors.
        });
    });
}

#pragma mark - Private

- (UIImage *)updateImageWithCurrentData:(NSData *)data pass:(NSUInteger)pass
{
    NSUInteger currentBytesPerPixel = self.pixelDepth/8;
    BOOL hasAlpha = (currentBytesPerPixel == 4);
    CGSize passImageSize = CGSizeMake(floorf(self.imageSize.width/(float)block_width[pass]), floorf(self.imageSize.height/(float)block_width[pass]));
    char *buffer = (char *)malloc(passImageSize.width*passImageSize.height*bytesPerPixel);
    
    for (int y=0; y<passImageSize.height; y++)
    {
        for (int x=0; x<passImageSize.width; x++)
        {
            NSUInteger blockWidth = block_width[pass];
            NSUInteger offset = (y*self.imageSize.width*blockWidth*currentBytesPerPixel) + (x*blockWidth*currentBytesPerPixel);
            NSUInteger bufferOffset = (y*passImageSize.width*bytesPerPixel) + (x*bytesPerPixel);
            
            uint32_t rgba;
            uint8_t alpha = 255;
            
            [data getBytes:&rgba range:NSMakeRange(offset, currentBytesPerPixel)];
            uint8_t red = (rgba >> 0) & 0xFF;
            uint8_t green = (rgba >> 8) & 0xFF;
            uint8_t blue = (rgba >> 16) & 0xFF;
            if (hasAlpha) alpha = (rgba >> 24) & 0xFF;
            
            buffer[bufferOffset] = red;
            buffer[bufferOffset+1] = green;
            buffer[bufferOffset+2] = blue;
            buffer[bufferOffset+3] = alpha;
        }
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(
                                                       buffer,
                                                       passImageSize.width,
                                                       passImageSize.height,
                                                       8, // bitsPerComponent
                                                       bytesPerPixel*passImageSize.width, // bytesPerRow
                                                       colorSpace,
                                                       (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CFRelease(colorSpace);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    UIImage *finalizedImage = [[UIImage alloc] initWithCGImage:cgImage];
    
    CFRelease(cgImage);
    CFRelease(bitmapContext);
    free(buffer);
    
    return finalizedImage;
}

@end
