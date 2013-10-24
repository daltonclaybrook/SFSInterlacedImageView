//
//  SFSViewController.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSViewController.h"
#import "SFSImageDataProvider.h"

@interface SFSViewController ()

@end

@implementation SFSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	SFSImageDataProvider *dataProvider = [[SFSImageDataProvider alloc] initWithImageURL:[[NSBundle mainBundle] URLForResource:@"future" withExtension:@"png"]];
    [dataProvider start];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
