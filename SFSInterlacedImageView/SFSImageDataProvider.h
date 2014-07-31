//
//  SFSImageDataProvider.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Bottle Rocket, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString * const SFSImageDataProviderDataProgressNotification = @"SFSImageDataProviderDataProgressNotification";

@protocol SFSImageDataProviderDelegate;

@interface SFSImageDataProvider : NSObject

@property (nonatomic, weak) id<SFSImageDataProviderDelegate> delegate;
@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic) NSTimeInterval minimumImageFetchInterval;
@property (nonatomic) NSUInteger firstPassToGenerate;

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