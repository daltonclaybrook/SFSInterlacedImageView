//
//  SFSViewController.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSViewController.h"
#import "SFSImageDataProvider.h"

@interface SFSViewController () <SFSImageDataProviderDelegate>

@property (nonatomic, strong) SFSImageDataProvider *dataProvider;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation SFSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
//	self.dataProvider = [[SFSImageDataProvider alloc] initWithImageURL:[[NSBundle mainBundle] URLForResource:@"future" withExtension:@"png"]];
    self.dataProvider = [[SFSImageDataProvider alloc] initWithImageURL:[NSURL URLWithString:@"http://s24.postimg.org/kimjbbmw5/future.png"]];
    self.dataProvider.delegate = self;
    [self.dataProvider start];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)imageDataProvider:(SFSImageDataProvider *)dataProvider receivedImage:(UIImage *)image
{
    self.imageView.image = image;
}

@end
