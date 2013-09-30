//
//  KLFTPTask.m
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

#import "KLFTPTask.h"

#define kTaskID             @"taskID"
#define kTaskSize           @"taskSize"
#define kFinishedSize       @"finishedSize"
#define kCurrentItemIndex   @"currentItemIndex"
#define kTransferType       @"transferType"
#define kTransferState      @"transferState"
#define kTransferItemArry   @"transferItemArray"

@implementation KLFTPTask

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.taskID forKey:kTaskID];
    [aCoder encodeInt64:self.taskSize forKey:kTaskSize];
    [aCoder encodeInt64:self.finishedSize forKey:kFinishedSize];
    [aCoder encodeInt:self.currentItemIndex forKey:kCurrentItemIndex];
    [aCoder encodeInt:self.transferType forKey:kTransferType];
    [aCoder encodeInt:self.transferState forKey:kTransferState];
    [aCoder encodeObject:self.transferItemArray forKey:kTransferItemArry];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _taskID = [aDecoder decodeObjectForKey:kTaskID];
        self.taskSize = [aDecoder decodeInt64ForKey:kTaskSize];
        self.finishedSize = [aDecoder decodeInt64ForKey:kFinishedSize];
        self.currentItemIndex = [aDecoder decodeIntForKey:kCurrentItemIndex];
        self.transferType = [aDecoder decodeIntForKey:kTransferType];
        self.transferState = [aDecoder decodeIntForKey:kTransferState];
        self.transferItemArray = [aDecoder decodeObjectForKey:kTransferItemArry];
        return self;
    }
    return nil;
}

#pragma mark - Private

- (BOOL)isTaskChangeable {
    //we can add item even if the task is being transferd, so just return YES;
    return YES;
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

#pragma mark - LifeCycle

- (id)init {
    self = [super init];
    if (self) {
        self.currentItemIndex = 0;
        self.taskSize = 0;
        self.finishedSize = 0;
        self.transferState = KLFTPTransferStateUnknown;
        self.transferType = KLFTPTransferTypeUnknown;
        _taskID = [NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]];
        return self;
    }
    return nil;
}

- (void)setTransferItemArray:(NSArray *)transferItemArray {
    _transferItemArray = transferItemArray;

    self.taskSize = 0;
    @synchronized (_transferItemArray) {
        for (KLFTPTransferItem * item in _transferItemArray) {
            self.taskSize += item.fileSize;
        }
    }
}

#pragma mark - Interface

- (BOOL)addTransferItem:(KLFTPTransferItem *)transferItem {
    KLFTPTransferType transType = [self transferTypeForItem:transferItem];
    [transferItem setTransferType:transType];
    
    if ([self isTaskChangeable]) {
        if (!self.transferItemArray) {
            self.transferItemArray = [[NSArray alloc] init];
        }
        NSMutableArray * tempArray = [NSMutableArray arrayWithArray:self.transferItemArray];
        [tempArray addObject:transferItem];
        [self setTransferItemArray:tempArray];
        return YES;
    }else {
        return NO;
    }
}

- (BOOL)removeTransferItem:(KLFTPTransferItem *)transferItem {
    if ([self isTaskChangeable]) {
        if ([self.transferItemArray containsObject:transferItem]) {
            NSMutableArray * tempArray = [NSMutableArray arrayWithArray:self.transferItemArray];
            [tempArray removeObject:transferItem];
            [self setTransferItemArray:tempArray];
        }
        return YES;
    }else {
        return NO;
    }
}

- (KLFTPTransferItem *)currentTransferItem {
    if (self.currentItemIndex < self.transferItemArray.count) {
        return [self.transferItemArray objectAtIndex:self.currentItemIndex];
    }
    return nil;
}

@end

