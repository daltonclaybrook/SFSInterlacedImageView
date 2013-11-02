//
//  SFSInterlacedImageView.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSInterlacedImageView.h"
#import "SFSImageDataProvider.h"

static NSTimeInterval const transitionDuration = 1.0f;

@interface SFSInterlacedImageView () <SFSImageDataProviderDelegate>

@property (nonatomic, strong) SFSImageDataProvider *dataProvider;
@property (nonatomic) BOOL transitioning;
@property (nonatomic, strong) UIImage *nextImage;

@end

@implementation SFSInterlacedImageView

#pragma mark - View Lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];
    _transitioning = NO;
}

#pragma mark - Properties

- (void)setImageURL:(NSURL *)imageURL
{
    _imageURL = imageURL;
    self.image = nil;
    
    [self.dataProvider cancel];
    [self.dataProvider start];
}

- (SFSImageDataProvider *)dataProvider
{
    if (!_dataProvider)
    {
        _dataProvider = [[SFSImageDataProvider alloc] initWithImageURL:self.imageURL];
        _dataProvider.delegate = self;
    }
    return _dataProvider;
}

#pragma mark - Private

- (void)animateTransition
{
    UIImage *transitionImage = self.nextImage;
    self.nextImage = nil;
    
    if (transitionImage)
    {
        self.transitioning = YES;
        [UIView transitionWithView:self duration:transitionDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self.image = transitionImage;
        } completion:^(BOOL finished) {
            self.transitioning = NO;
            if (finished && self.nextImage)
            {
                [self animateTransition];
            }
        }];
    }
}

#pragma mark - SFSImageDataProviderDelegate

- (void)imageDataProviderCompletedLoading:(SFSImageDataProvider *)dataProvider
{
    if ([self.delegate respondsToSelector:@selector(interlacedImageViewFinishedLoading:)])
    {
        [self.delegate interlacedImageViewFinishedLoading:self];
    }
}

- (void)imageDataProvider:(SFSImageDataProvider *)dataProvider failedWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(interlacedImageView:failedWithError:)])
    {
        [self.delegate interlacedImageView:self failedWithError:error];
    }
}

- (void)imageDataProvider:(SFSImageDataProvider *)dataProvider receivedImage:(UIImage *)image
{
    self.nextImage = image;
    if (!self.transitioning)
    {
        [self animateTransition];
    }
}

@end
