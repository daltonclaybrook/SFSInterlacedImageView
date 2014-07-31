//
//  SFSViewController.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 7/30/14.
//  Copyright (c) 2014 Space Factory Studios. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFSInterlacedImageView.h"

@interface SFSViewController : UIViewController

@property (weak, nonatomic) IBOutlet SFSInterlacedImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *passSelector;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end
