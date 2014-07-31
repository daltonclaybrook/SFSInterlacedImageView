//
//  SFSViewController.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 7/30/14.
//  Copyright (c) 2014 Space Factory Studios. All rights reserved.
//

#import "SFSViewController.h"
#import "SFSImageDataProvider.h"

@interface SFSViewController () <SFSInterlacedImageViewDelegate>

@end

@implementation SFSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageView.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageViewMadeProgress:) name:SFSImageDataProviderDataProgressNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (IBAction)restartTapped:(id)sender
{
    self.loadingLabel.text = @"Loading...";
    self.progressView.progress = 0.0f;
    self.imageView.firstPassToGenerate = [self.passSelector selectedSegmentIndex];
    self.imageView.transitionDuration = 2.0f;
    self.imageView.imageURL = [NSURL URLWithString:@"http://daltonclaybrook.com/future.png"];
}

#pragma mark - Private

- (void)imageViewMadeProgress:(NSNotification *)notification
{
    NSNumber *progress = notification.object;
    self.progressView.progress = progress.floatValue;
}

#pragma mark - SFSInterlacedImageViewDelegate

- (void)interlacedImageViewFinishedLoading:(SFSInterlacedImageView *)imageView
{
    self.loadingLabel.text = @"Finished";
}

- (void)interlacedImageView:(SFSInterlacedImageView *)imageView failedWithError:(NSError *)error
{
    self.loadingLabel.text = @"Failed";
}

@end
