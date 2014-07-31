//
//  SFSInterlacedImageView.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Bottle Rocket, LLC. All rights reserved.
//

#import "SFSInterlacedImageView.h"
#import "SFSImageDataProvider.h"

@interface SFSInterlacedImageView () <SFSImageDataProviderDelegate>

@property (nonatomic, strong) SFSImageDataProvider *dataProvider;
@property (nonatomic) BOOL transitioning;
@property (nonatomic, strong) UIImage *nextImage;

@end

@implementation SFSInterlacedImageView

#pragma mark - View Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self SFSInterlacedImageViewCommonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self SFSInterlacedImageViewCommonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self SFSInterlacedImageViewCommonInit];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithImage:image];
    if (self)
    {
        [self SFSInterlacedImageViewCommonInit];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
    self = [super initWithImage:image highlightedImage:highlightedImage];
    if (self)
    {
        [self SFSInterlacedImageViewCommonInit];
    }
    return self;
}

#pragma mark - Properties

- (void)setImageURL:(NSURL *)imageURL
{
    _imageURL = imageURL;
    self.dataProvider.imageURL = imageURL;
    self.image = nil;
    
    [self.dataProvider cancel];
    [self.dataProvider start];
}

- (void)setFirstPassToGenerate:(NSUInteger)firstPassToGenerate
{
    _firstPassToGenerate = (firstPassToGenerate > 6) ? 6 : firstPassToGenerate;
    self.dataProvider.firstPassToGenerate = _firstPassToGenerate;
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

- (void)SFSInterlacedImageViewCommonInit
{
    _transitioning = NO;
    _firstPassToGenerate = 1;
    _transitionDuration = 1.0f;
}

- (void)animateTransition
{
    UIImage *transitionImage = self.nextImage;
    self.nextImage = nil;
    
    if (transitionImage)
    {
        self.transitioning = YES;
        [UIView transitionWithView:self duration:self.transitionDuration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
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
    if (!self.image)
    {
        self.image = image;
        return;
    }
    
    self.nextImage = image;
    if (!self.transitioning)
    {
        [self animateTransition];
    }
}

@end
