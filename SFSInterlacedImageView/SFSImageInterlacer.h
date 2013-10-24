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

- (void)createImageFromInterlacedData:(NSData *)data completion:(SFSImageInterlacerCompletionBlock)completion;

@end
