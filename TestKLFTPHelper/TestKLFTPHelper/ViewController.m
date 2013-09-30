//
//  ViewController.m
//  TestKLFTPHelper
//
//  Created by kinglonghuang on 8/14/13.
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

#import "ViewController.h"
#import "TaskTransferView.h"
#import "KLFTPAccount.h"
#import "KLFTPTransferItem.h"

#define SliderTagOffset     2000

@interface ViewController ()

@property (nonatomic, strong) UIView    * touchView;

@end

@implementation ViewController

#pragma mark - Private

- (NSURL *)localFileURLForRemoteFileName:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString * urlStr = [[paths lastObject] stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:urlStr];
}

- (NSArray *)transferItemArray
{
    KLFTPAccount * account = [[KLFTPAccount alloc] init];
    [account setUserName:@"FTPUserName"];
    [account setPassword:@"FTPPassword"];
    
    NSString * downloadURLStr = @"ftp://10.10.92.99/item1.dmg";
    downloadURLStr = [downloadURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL * ftpDownloadURL = [NSURL URLWithString:downloadURLStr];
    NSURL *  localUrl = [self localFileURLForRemoteFileName:[ftpDownloadURL lastPathComponent]];
    KLFTPTransferItem * downloadItem = [[KLFTPTransferItem alloc] init];
    [downloadItem setSrcURL:ftpDownloadURL];
    [downloadItem setDestURL:localUrl];
    [downloadItem setFileSize:72534528];
    [downloadItem setAccount:account];
    
    NSString * uploadURLStr = @"ftp://10.10.92.99/Test/Foler/Creation/item1.dmg";
    uploadURLStr = [uploadURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *ftpUploadURL1 = [NSURL URLWithString:uploadURLStr];
    NSURL *  localUrlUp1 = [self localFileURLForRemoteFileName:[ftpUploadURL1 lastPathComponent]];
    KLFTPTransferItem * uploadItem = [[KLFTPTransferItem alloc] init];
    [uploadItem setSrcURL:localUrlUp1];
    [uploadItem setDestURL:ftpUploadURL1];
    [uploadItem setFileSize:72534528];
    [uploadItem setAccount:account];
    
    return [NSArray arrayWithObjects:downloadItem,uploadItem, nil];
}

- (void)layoutTaskViews {
    //Select the item you want to transfer
    KLFTPTransferItem * item = [[self transferItemArray] objectAtIndex:1];
    
    CGFloat viewHeight = [TaskTransferView viewHeight];
    CGRect frame = CGRectMake(10, 20, self.view.frame.size.width-20, viewHeight);
    TaskTransferView * transferView = [[TaskTransferView alloc] initWithFrame:frame];
    [transferView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [transferView setTransferItem:item];
    [transferView setTransferState:item.transferState];
    [self.view addSubview:transferView];
    [transferView updateUIWithState:item.transferState percent:0 transferDes:@""];
}

#pragma mark - LifeCycle

- (void)loadView {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIView * view = [[UIView alloc] initWithFrame:bounds];
    [view setBackgroundColor:[UIColor whiteColor]];
    [self setView:view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self layoutTaskViews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

@end
