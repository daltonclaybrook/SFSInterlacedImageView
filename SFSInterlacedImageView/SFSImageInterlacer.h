//
//  SFSImageInterlacer.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^SFSImageInterlacerCompletionBlock)(UIImage *image, NSError *error);

@interface SFSImageInterlacer : NSObject

@property (nonatomic) BOOL generatingImage;

- (instancetype)initWithSize:(CGSize)size pixelDepth:(NSUInteger)depth;
- (void)updateImageWithRow:(NSUInteger)row data:(NSData *)rowData pass:(NSUInteger)pass completion:(SFSImageInterlacerCompletionBlock)completion;
- (void)updateImageWithCurrentData:(NSData *)data lastCompletedRow:(NSUInteger)row pass:(NSUInteger)pass completion:(SFSImageInterlacerCompletionBlock)completion;

@end
