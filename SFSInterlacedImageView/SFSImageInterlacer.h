//
//  SFSImageInterlacer.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Bottle Rocket, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^SFSImageInterlacerCompletionBlock)(UIImage *image, NSError *error);

@interface SFSImageInterlacer : NSObject

@property (nonatomic) BOOL generatingImage;

- (instancetype)initWithSize:(CGSize)size pixelDepth:(NSUInteger)depth;
- (void)updateImageWithCurrentData:(NSData *)data pass:(NSUInteger)pass completion:(SFSImageInterlacerCompletionBlock)completion;

@end
