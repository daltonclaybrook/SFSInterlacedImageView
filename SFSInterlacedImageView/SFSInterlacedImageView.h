//
//  SFSInterlacedImageView.h
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SFSInterlacedImageViewDelegate;

@interface SFSInterlacedImageView : UIImageView

@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, weak) id<SFSInterlacedImageViewDelegate> delegate;

@end

@protocol SFSInterlacedImageViewDelegate <NSObject>
@optional

- (void)interlacedImageViewFinishedLoading:(SFSInterlacedImageView *)imageView;
- (void)interlacedImageView:(SFSInterlacedImageView *)imageView failedWithError:(NSError *)error;

@end