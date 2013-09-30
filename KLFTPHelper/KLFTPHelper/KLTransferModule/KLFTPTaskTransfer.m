//
//  KLFTPTaskTransfer.m
//  TestKLFTPHelper
//
//  Created by kinglonghuang on 8/15/13.
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

#import "KLFTPTaskTransfer.h"

@interface KLFTPTaskTransfer()

@property (nonatomic, strong) KLFTPDownloader      * ftpDownloader;

@property (nonatomic, strong) KLFTPUploader        * ftpUploader;

@end

@implementation KLFTPTaskTransfer

#pragma mark - LifeCycle

- (void)setTask:(KLFTPTask *)task {
    if ([_task.taskID isEqualToString:task.taskID]) {
        return;
    }else {
        _task = task;
    }
}

#pragma mark - Private

- (KLFTPTransferItem *)currentTransferItem {
    KLFTPTransferItem * item = [self.task.transferItemArray objectAtIndex:self.task.currentItemIndex];
    return item;
}

- (KLFTPTransferType)transferTypeForItem:(KLFTPTransferItem *)item {
    NSString * protocolForSrc = [item.srcURL scheme];
    NSString * protocolForDest = [item.destURL scheme];
    if ([protocolForSrc isEqualToString:@"ftp"]) {
        return KLFTPTransferTypeDownload;
    }else if ([protocolForDest isEqualToString:@"ftp"]) {
        return KLFTPTransferTypeUpload;
    }else {
        return KLFTPTransferTypeUnknown;
    }
}

- (KLFTPTransfer *)transferForItem:(KLFTPTransferItem *)item {
    if (item.transferType == KLFTPTransferTypeDownload) {
        if (!self.ftpDownloader) {
            self.ftpDownloader = [[KLFTPDownloader alloc] init];
        }
        return self.ftpDownloader;
    }else if (item.transferType == KLFTPTransferTypeUpload) {
        if (!self.ftpUploader) {
            self.ftpUploader = [[KLFTPUploader alloc] init];
        }
        return self.ftpUploader;
    }else {
        return nil;
    }
}

- (BOOL)transferCurrentItem {
    NSInteger index = self.task.currentItemIndex;
    NSInteger count = self.task.transferItemArray.count;
    if (index < count) {
        KLFTPTransferItem * currentItem = [self currentTransferItem];
        KLFTPTransfer * transfer = [self transferForItem:currentItem];
        [transfer setTransferItem:currentItem];
        [transfer setDelegate:self];
        BOOL result = [transfer start];
        [self.task setTransferType:[self transferTypeForItem:currentItem]];
        [self.task setTransferState:currentItem.transferState];
        return result;
    }
    return NO;
}

- (KLFTPTransferState)transferingStateForItem:(KLFTPTransferItem *)item {
    KLFTPTransferState state = (item.transferType == KLFTPTransferTypeUpload) ? KLFTPTransferStateUploading : KLFTPTransferStateDownloading;
    return state;
}

- (uint64_t)finishedSizeForTask:(KLFTPTask *)task {
    uint64_t result = 0;
    for (KLFTPTransferItem * item in task.transferItemArray) {
        result += item.finishedSize;
    }
    return result;
}

#pragma mark - StateChange

#pragma mark - Interface

- (BOOL)start {
    if (self.task.transferState & KLFTPTransferStateMaskTransfering) {
        return YES;
    }
    
    if ([self transferCurrentItem]) {
        KLFTPTransferState state = [self transferingStateForItem:[self currentTransferItem]];
        self.task.transferState = state;
    }
    return YES;
}

- (BOOL)pause {
    if (self.task.transferState & KLFTPTransferStateMaskTransfering) {
        KLFTPTransfer * transfer = [self transferForItem:[self currentTransferItem]];
        if ([transfer pause]) {
            self.task.transferState = KLFTPTransferStatePaused;
            return YES;
        }else {
            return NO;
        }
    }
    return NO;
}

- (BOOL)resume {
    if (self.task.transferState == KLFTPTransferStatePaused) {
        KLFTPTransfer * transfer = [self transferForItem:[self currentTransferItem]];
        if ([transfer resume]) {
            KLFTPTransferState state = [self transferingStateForItem:[self currentTransferItem]];
            self.task.transferState = state;
            return YES;
        }else {
            return NO;
        }
    }
    return NO;
}

- (BOOL)stop {
    if (self.task.transferState != KLFTPTransferStateStopped) {
        KLFTPTransfer * transfer = [self transferForItem:[self currentTransferItem]];
        if ([transfer stop]) {
            self.task.finishedSize = 0;
            self.task.currentItemIndex = 0;
            self.task.transferState = KLFTPTransferStateStopped;
            return YES;
        }else {
            return NO;
        }
    }
    return YES;
}

#pragma mark - TransferDelegate

- (void)klFTPTransfer:(KLFTPTransfer *)transfer progressChangedForItem:(KLFTPTransferItem *)item {
    static uint32_t detaSize = 0;
    if (self.task.transferState & KLFTPTransferStateMaskTransfering) {
        uint64_t finishedSizeBefore = self.task.finishedSize;
        [self.task setFinishedSize:[self finishedSizeForTask:self.task]];
        detaSize += self.task.finishedSize - finishedSizeBefore;
        BOOL shouldReportChange = detaSize/(CGFloat)self.task.taskSize >= 0.006 ? YES : NO;
        BOOL isFinished = item.finishedSize >= item.fileSize ? YES : NO;
        shouldReportChange = shouldReportChange | isFinished;
        if (shouldReportChange && [self.delegate respondsToSelector:@selector(taskTransfer:progressChangedForTask:)]) {
            detaSize = 0;
            [self.delegate taskTransfer:self progressChangedForTask:self.task];
        }
    }
}

- (void)klFTPTransfer:(KLFTPTransfer *)transfer transferStateDidChangedForItem:(KLFTPTransferItem *)item error:(NSError *)error {
    if (item.transferState == KLFTPTransferStateFinished) {
        self.task.currentItemIndex++;
        [self.task setFinishedSize:[self finishedSizeForTask:self.task]];
        if (self.task.currentItemIndex < self.task.transferItemArray.count) {
            [self transferCurrentItem];
        }else if (self.task.finishedSize >= self.task.taskSize){
            //update the task state
            self.task.transferState = KLFTPTransferStateFinished;
            if ([self.delegate respondsToSelector:@selector(taskTransfer:transferStateDidChangedForTask:error:)]) {
                [self.delegate taskTransfer:self transferStateDidChangedForTask:self.task error:error];
            }
        }
    }else {
        [self.task setTransferState:item.transferState];
        if ([self.delegate respondsToSelector:@selector(taskTransfer:transferStateDidChangedForTask:error:)]) {
            [self.delegate taskTransfer:self transferStateDidChangedForTask:self.task error:error];
        }
    }
}

@end
