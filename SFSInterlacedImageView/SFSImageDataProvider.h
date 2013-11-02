//
//  SFSImageDataProvider.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SFSImageDataProviderDelegate;

@interface SFSImageDataProvider : NSObject

@property (nonatomic, weak) id<SFSImageDataProviderDelegate> delegate;
@property (nonatomic, strong, readonly) NSURL *imageURL;
@property (nonatomic) NSTimeInterval minimumImageFetchInterval;

- (instancetype)initWithImageURL:(NSURL *)url;
- (void)start;
- (void)cancel;

@end

@protocol SFSImageDataProviderDelegate <NSObject>
@optional

- (void)imageDataProviderCompletedLoading:(SFSImageDataProvider *)dataProvider;
- (void)imageDataProvider:(SFSImageDataProvider *)dataProvider failedWithError:(NSError *)error;
- (void)imageDataProvider:(SFSImageDataProvider *)dataProvider receivedImage:(UIImage *)image;

@end