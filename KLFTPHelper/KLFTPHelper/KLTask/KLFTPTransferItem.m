//
//  DFFTPTransItem.m
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

#define kItemID         @"itemID"
#define kItemName       @"itemName"
#define kSrcURL         @"srcURL"
#define kDestURL        @"destURL"
#define kFileSize       @"fileSize"
#define kFinishedSize   @"finishedSize"
#define kTransferType   @"transferType"
#define kTransferState  @"transferState"
#define kAccount        @"account"

#import "KLFTPTransferItem.h"

@implementation KLFTPTransferItem

#pragma mark - Private

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

- (NSString *)itemName {
    if (![_itemName length]) {
        _itemName = [self.srcURL lastPathComponent];
    }
    return _itemName;
}

- (id)init {
    self = [super init];
    if (self) {
        _itemID = [NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]];
        return self;
    }
    return self;
}

- (void)setDestURL:(NSURL *)destURL {
    _destURL = destURL;
    [self setTransferType:[self transferTypeForItem:self]];
}

- (void)setSrcURL:(NSURL *)srcURL {
    _srcURL = srcURL;
    [self setTransferType:[self transferTypeForItem:self]];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.itemID forKey:kItemID];
    [encoder encodeObject:self.itemName forKey:kItemName];
    [encoder encodeObject:self.srcURL forKey:kSrcURL];
    [encoder encodeObject:self.destURL forKey:kDestURL];
    [encoder encodeInt64:self.fileSize forKey:kFileSize];
    [encoder encodeInt64:self.finishedSize forKey:kFinishedSize];
    [encoder encodeInt:self.transferType forKey:kTransferType];
    [encoder encodeInt:self.transferState forKey:kTransferState];
    [encoder encodeObject:self.account forKey:kAccount];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _itemID = [decoder decodeObjectForKey:kItemID];
        self.itemName = [decoder decodeObjectForKey:kItemName];
        self.srcURL = [decoder decodeObjectForKey:kSrcURL];
        self.destURL = [decoder decodeObjectForKey:kDestURL];
        self.fileSize = [decoder decodeInt64ForKey:kFileSize];
        self.finishedSize = [decoder decodeInt64ForKey:kFinishedSize];
        self.transferType = [decoder decodeIntForKey:kTransferType];
        self.transferState = [decoder decodeIntForKey:kTransferState];
        self.account = [decoder decodeObjectForKey:kAccount];
    }
    return self;
}

@end
