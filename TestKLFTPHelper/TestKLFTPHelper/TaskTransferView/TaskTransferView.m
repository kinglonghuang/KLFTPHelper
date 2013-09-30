//
//  TaskTransferView.m
//  TestKLFTPHelper
//
//  Created by kinglonghuang on 8/22/13.
/*
 * https://github.com/kinglonghuang/KLFTPHelper
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 *
 * Copyright (c) 2013 KLStudio.(kinglong.huang) All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Wei
 * Wang nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */

#import "TaskTransferView.h"
#import "KLFTPHelper.h"
#import "KLFTPTransfer.h"

@interface TaskTransferView()

@property (nonatomic, strong) UILabel           * transferDesLabel;

@property (nonatomic, strong) UISlider          * progressSlider;

@property (nonatomic, strong) UIButton          * startOrStopBtn;

@property (nonatomic, strong) UIButton          * pauseOrResumeBtn;

@property (nonatomic, strong) KLFTPTransfer    * itemTransfer;

@end

@implementation TaskTransferView

#pragma mark - Private

- (NSString *)transferInfoStr {
    switch (self.transferState) {
        case KLFTPTransferStateDownloading: {
            return [NSString stringWithFormat:@"%@ %@",@"Downloading",self.transferDes];
        }
        case KLFTPTransferStateUploading: {
            return [NSString stringWithFormat:@"%@ %@",@"Uploading",self.transferDes];
        }
        case KLFTPTransferStatePending: {
            return @"Pending";
        }
        case KLFTPTransferStateReady: {
            return @"Ready";
        }
        case KLFTPTransferStateFailed: {
            return [NSString stringWithFormat:@"%@ %@",@"Failed",self.transferDes];
        }
        case KLFTPTransferStateStopped: {
            return @"Stopped";
        }
        case KLFTPTransferStateFinished: {
            return @"Finished";
        }
        case KLFTPTransferStatePaused: {
            return @"Paused";
        }
        case KLFTPTransferStateUnknown: {
            return @"Unknown";
        }
        default:
            return @"";
            break;
    }
}

- (NSURL *)localFileURLForRemoteFileName:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString * urlStr = [[paths lastObject] stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:urlStr];
}

- (void)layoutUI {
    
    self.transferDesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 20)];
    [self.transferDesLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self addSubview:self.transferDesLabel];
    
    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 20, self.frame.size.width, 29)];
    [self.progressSlider setUserInteractionEnabled:NO];
    [self.progressSlider setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.progressSlider setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.progressSlider setThumbImage:nil forState:UIControlStateNormal];
    [self addSubview:self.progressSlider];
    
    self.startOrStopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.startOrStopBtn setFrame:CGRectMake(self.frame.size.width-140, CGRectGetMaxY(self.progressSlider.frame), 60, 30)];
    [self.startOrStopBtn setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [self.startOrStopBtn setBackgroundColor:[UIColor grayColor]];
    [self.startOrStopBtn setTitle:@"Start" forState:UIControlStateNormal];
    [self.startOrStopBtn setSelected:NO];
    [self.startOrStopBtn setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [self.startOrStopBtn addTarget:self action:@selector(startOrStop:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.startOrStopBtn];
    
    self.pauseOrResumeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.pauseOrResumeBtn setFrame:CGRectMake(self.frame.size.width-70, CGRectGetMaxY(self.progressSlider.frame), 70, 30)];
    [self.pauseOrResumeBtn setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [self.pauseOrResumeBtn setBackgroundColor:[UIColor grayColor]];
    [self.pauseOrResumeBtn setTitle:@"Pause" forState:UIControlStateNormal];
    [self.pauseOrResumeBtn setSelected:NO];
    [self.pauseOrResumeBtn setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
    [self.pauseOrResumeBtn addTarget:self action:@selector(pauseOrResume:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.pauseOrResumeBtn];
}

#pragma mark - Action

- (void)startOrStop:(UIButton *)btn {
    BOOL shouldStart = !btn.isSelected;
    if (shouldStart) {
        [self.itemTransfer start];
        if (self.transferItem.transferState & KLFTPTransferStateMaskTransfering) {
            [btn setTitle:@"Stop" forState:UIControlStateNormal];
        }
    }else {
        [self.itemTransfer stop];
        if (self.transferItem.transferState == KLFTPTransferStateStopped) {
            [btn setTitle:@"Start" forState:UIControlStateNormal];
        }
    }
    
    [btn setSelected:!btn.isSelected];
}

- (void)pauseOrResume:(UIButton *)btn {
    BOOL shouldPause = !btn.isSelected;
    if (shouldPause) {
        [self.itemTransfer pause];
        if (self.transferItem.transferState == KLFTPTransferStatePaused) {
            [btn setTitle:@"Resume" forState:UIControlStateNormal];
        }
    }else {
        [self.itemTransfer resume];
        if (self.transferItem.transferState & KLFTPTransferStateMaskTransfering) {
            [btn setTitle:@"Pause" forState:UIControlStateNormal];
        }
    }
    
    [btn setSelected:!btn.isSelected];
}

#pragma mark - LifeCycle

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self layoutUI];
        return self;
    }
    return nil;
}

- (void)setTransferItem:(KLFTPTransferItem *)transferItem {
    _transferItem = transferItem;
    self.itemTransfer = [KLFTPTransfer transferWithItem:transferItem];
    [self.itemTransfer setTransferItem:transferItem];
    [self.itemTransfer setDelegate:self];
}

#pragma mark - Interface

+ (CGFloat)viewHeight {
    UISlider * slider = [[UISlider alloc] init];
    CGFloat height = slider.frame.size.height + 50;
    return height;
}

- (void)updateUIWithState:(KLFTPTransferState)state percent:(CGFloat)percent transferDes:(NSString *)des {
    self.transferState = state;
    self.transferPercent = percent;
    self.transferDes = des;
    //update the UI
    NSLog(@"The percent is %f",percent);
    [self.transferDesLabel setText:[self transferInfoStr]];
    [self.progressSlider setValue:percent animated:NO];
}

#pragma mark - KLFTPTransferDelegate

- (void)klFTPTransfer:(KLFTPTransfer *)transfer transferStateDidChangedForItem:(KLFTPTransferItem *)item error:(NSError *)error {
    //update the transferView UI
    NSString * des = nil;
    if (error) {
        des = [NSString stringWithFormat:@"ErrorCode:%d",error.code];
    }else {
        des = [NSString stringWithFormat:@"%@",item.itemName];
    }
    CGFloat percent = item.finishedSize/(CGFloat)item.fileSize;
    [self updateUIWithState:item.transferState percent:percent transferDes:des];
}

- (void)klFTPTransfer:(KLFTPTransfer *)transfer progressChangedForItem:(KLFTPTransferItem *)item {
    CGFloat percent = item.finishedSize/(CGFloat)item.fileSize;
    NSString * des = [NSString stringWithFormat:@"%@",item.itemName];
    [self updateUIWithState:item.transferState percent:percent transferDes:des];
}

@end
