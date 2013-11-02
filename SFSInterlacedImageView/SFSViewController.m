//
//  SFSViewController.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSViewController.h"
#import "SFSInterlacedImageView.h"

@interface SFSViewController () <SFSInterlacedImageViewDelegate>

@property (strong, nonatomic) IBOutlet SFSInterlacedImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;

@end

@implementation SFSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageView.delegate = self;
    self.imageView.imageURL = [NSURL URLWithString:@"http://daltonclaybrook.com/future.png"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)restartTapped:(id)sender
{
    self.loadingLabel.text = @"Loading";
    self.imageView.imageURL = [NSURL URLWithString:@"http://daltonclaybrook.com/future.png"];
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
