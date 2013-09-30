//
//  KLFTPUploader.m
//  FTPSocket
//
//  Created by kinglonghuang on 8/20/13.
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

#import "KLFTPUploader.h"
#import "GCDAsyncSocket.h"

#define WRITE_TAG       100011

typedef enum {
    FTPReturnCode_UnDefined                 = -1,
    FTPReturnCode_ConnectionEstablished     = 220,
    FTPReturnCode_AskForPassword            = 331,
    FTPReturnCode_UserOnLine                = 230,
    FTPReturnCode_CwdFinished               = 250,
    FTPReturnCode_FileSizeRetrived          = 213,
    FTPReturnCode_EnterPassiveMode          = 227,
    FTPReturnCode_DirCreateSucceed          = 257,
    FTPReturnCode_ReadyToTransfer           = 150,
    FTPReturnCode_FileNotFound              = 550,
}FTPReturnCode;

@interface KLFTPUploader()

@property (nonatomic, strong) NSInputStream         * readStream;

@property (nonatomic, strong) GCDAsyncSocket        * tcpSocket;

@property (nonatomic, strong) GCDAsyncSocket        * writeSocket;

@property (nonatomic, assign) size_t                bytesWritten;

@property (nonatomic, assign) uint16_t              pasvPort;

@property (atomic, assign) BOOL                     shouldPause;

@property (atomic, assign) BOOL                     shouldStop;

@property (nonatomic, strong) NSMutableArray        * pathArray;

@property (nonatomic, assign) NSInteger             currentPathIndex;

@property (nonatomic, assign) BOOL                  shouldCreateDir;

@property (nonatomic, assign) BOOL                  isFileSizeCmdSend;

@end

@implementation KLFTPUploader

#pragma mark - Private

- (BOOL)connectToFTPAndStartTransfer {
    NSString * host = [self.transferItem.destURL host];
    if (host) {
        self.tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
        NSError * error = nil;
        [self.tcpSocket connectToHost:host onPort:21 error:&error];
        [self.tcpSocket readDataWithTimeout:-1 tag:0];
        return !!error ? NO : YES;
    }
    return NO;
}

- (void)sendCmd:(NSString *)cmd {
    cmd = [cmd stringByAppendingString:@"\r\n"];
    NSData * cmdData = [NSData dataWithBytes:[cmd UTF8String] length:cmd.length];
    [self.tcpSocket writeData:cmdData withTimeout:-1 tag:0];
    [self.tcpSocket readDataWithTimeout:-1 tag:1];
}

- (KLFTPTransferState)transferingStateForTransferItem:(KLFTPTransferItem *)item {
    KLFTPTransferState state = (self.transferItem.transferType == KLFTPTransferTypeUpload) ? KLFTPTransferStateUploading : KLFTPTransferStateDownloading;
    return state;
}

- (FTPReturnCode)ftpReturnCodeWithString:(NSString *)str {
    NSArray * compents = [str componentsSeparatedByString:@" "];
    if ([compents count]) {
        NSString * code = [[str componentsSeparatedByString:@" "] objectAtIndex:0];
        return [code integerValue];
    }
    return FTPReturnCode_UnDefined;
}

- (uint64_t)fileSizeAtPath:(NSString *)filePath {
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSDictionary  * dict = [fileManager attributesOfItemAtPath:filePath error:nil];
	return [dict fileSize];
}

- (BOOL)isFileExitAtPath:(NSString *)filePath {
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

- (NSInteger)portFromFTPRetureStr:(NSString *)resultStr {
    NSArray * array = [resultStr componentsSeparatedByString:@" "];
    if ([[array objectAtIndex:0] isEqualToString:@"227"]) {
        NSString * ipDes = [array lastObject];
        NSArray * strArray = [ipDes componentsSeparatedByString:@","];
        NSString * portFront = [strArray objectAtIndex:[strArray count]-2];
        NSString * portEnd = [strArray objectAtIndex:[strArray count]-1];
        portEnd = [portEnd substringToIndex:portEnd.length-3];
        NSInteger port = [portFront intValue]*256 + [portEnd intValue];
        return port;
    }
    return -1;
}

- (BOOL)prepareTransferSocketAtPort:(NSInteger)port {
    NSString * host = [self.transferItem.destURL host];
    if (host) {
        self.writeSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
        NSError * error = nil;
        [self.writeSocket connectToHost:host onPort:port error:&error];
        [self.transferItem setFileSize:[self fileSizeAtPath:self.transferItem.srcURL.path]];
        self.readStream = [NSInputStream inputStreamWithFileAtPath:self.transferItem.srcURL.path];
        [self.readStream setProperty:[NSNumber numberWithUnsignedLongLong:self.transferItem.finishedSize] forKey:NSStreamFileCurrentOffsetKey];
        [self.readStream open];
        return !!error ? NO : YES;
    }
    return NO;
}

- (NSError *)errorWithCode:(IDFFTPErrorCode)errorCode msg:(NSString *)msg {
    msg = [msg length] ? msg : @"";
    NSDictionary * errorInfo = [NSDictionary dictionaryWithObject:msg forKey:@"errorMsg"];
    NSError * error = [[NSError alloc] initWithDomain:IDFFTPErrorDomain code:errorCode userInfo:errorInfo];
    return error;
}

- (void)checkFinishedSizeWithResultStr:(NSString *)retStr returnCode:(FTPReturnCode)retCode {
    if (retCode == FTPReturnCode_FileSizeRetrived) {
        NSArray * compents = [retStr componentsSeparatedByString:@" "];
        if ([compents count] > 1) {
            uint64_t fileSize = [[compents objectAtIndex:1] longLongValue];
            self.transferItem.finishedSize = fileSize;
        }
    }
}

- (void)checkFileSize {
    [self.transferItem setFileSize:[self fileSizeAtPath:self.transferItem.srcURL.path]];
}

- (void)resetState {
    self.shouldStop = NO;
    self.shouldPause = NO;
    self.shouldCreateDir = NO;
    self.isFileSizeCmdSend = NO;
    self.currentPathIndex = -1;
    [self.pathArray removeAllObjects];self.pathArray = nil;
}

- (void)fileSizeDeterminedWithResultStr:(NSString *)resultStr returnCode:(FTPReturnCode)retCode {
    [self checkFinishedSizeWithResultStr:resultStr returnCode:retCode];
    [self checkFileSize];
    if (self.transferItem.finishedSize >= self.transferItem.fileSize) {
        [self transferProgressDidChangedWithDetaSize:self.transferItem.finishedSize];
        [self transferDidFinished];
    }else {
        [self sendCmd:[self enterPasvModeCmd]];
    }
}

- (void)closeTransferStreams {
    [self.writeSocket disconnect];
    self.writeSocket = nil;
    
    [self.tcpSocket disconnect];
    self.tcpSocket = nil;
}

- (void)transferStoppedWithError:(NSError *)error {
    [self sendCmd:[self deleteCmd]];
    self.transferItem.finishedSize = 0;
    self.transferItem.transferState = error ? KLFTPTransferStateFailed : KLFTPTransferStateStopped;;
    [self closeTransferStreams];
    [[NSFileManager defaultManager] removeItemAtPath:self.transferItem.destURL.path error:nil];
    [self transferStateDidChangeWithError:error];
}

- (void)transferStateDidChangeWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(klFTPTransfer:transferStateDidChangedForItem:error:)]) {
            [self.delegate klFTPTransfer:self transferStateDidChangedForItem:self.transferItem error:error];
        }
    });
}

#pragma mark - TransferStateChange

- (void)transferProgressDidChangedWithDetaSize:(uint64_t)detaSize {
    static uint32_t sumDetaSize = 0;
    sumDetaSize += detaSize;
    BOOL shouldReport = sumDetaSize / (CGFloat)self.transferItem.fileSize >= 0.006 ? YES : NO;
    if (shouldReport) {
        sumDetaSize = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(klFTPTransfer:progressChangedForItem:)]) {
                [self.delegate klFTPTransfer:self progressChangedForItem:self.transferItem];
            }
        });
    }
}

- (void)transferDidFinished {
    [self closeTransferStreams];
    self.transferItem.transferState = KLFTPTransferStateFinished;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(klFTPTransfer:transferStateDidChangedForItem:error:)]) {
            [self.delegate klFTPTransfer:self transferStateDidChangedForItem:self.transferItem error:nil];
        }
    });
}

#pragma mark - Path

- (BOOL)isInDestDir {
    return self.currentPathIndex == (self.pathArray.count - 1);
}

- (NSString *)currentPath {
    if (!self.pathArray) {
        NSString * path = [[self.transferItem.destURL path] stringByDeletingLastPathComponent];
        self.pathArray = [NSMutableArray arrayWithArray:[path componentsSeparatedByString:@"/"]];
        [self.pathArray replaceObjectAtIndex:0 withObject:@"/"];
        self.currentPathIndex = self.pathArray.count - 1;
    }
    NSString * result = @"";
    if (self.currentPathIndex < self.pathArray.count) {
        for (int index = 0; index <= self.currentPathIndex; index++) {
            result = [result stringByAppendingString:[self.pathArray objectAtIndex:index]];
            if (index > 0) { //index 0 is @"/"
                result = [result stringByAppendingString:@"/"];
            }
        }
    }
    return result;
}

#pragma mark - CMD

- (NSString *)loginUserCmd {
    NSString * cmd = [NSString stringWithFormat:@"USER %@",self.transferItem.account.userName];
    return cmd;
}

- (NSString *)loginPasswordCmd {
    NSString * cmd = [NSString stringWithFormat:@"PASS %@",self.transferItem.account.password];
    return cmd;
}

- (NSString *)cwdCmd {
    NSString * currentPath = [self currentPath];
    NSString * cmd = [NSString stringWithFormat:@"CWD %@",currentPath];
    return cmd;
}

- (NSString *)enterPasvModeCmd {
    NSString * cmd = @"PASV";
    return cmd;
}

- (NSString *)fileSizeCmd {
    NSString * cmd = [NSString stringWithFormat:@"SIZE %@",[self.transferItem.destURL path]];
    return cmd;
}

- (NSString *)createDirCmd {
    NSString * path = [self currentPath];
    NSString * cmd = [NSString stringWithFormat:@"MKD %@",path];
    return cmd;
}

- (NSString *)appeCmd {
    NSString * filePath = [self.transferItem.destURL path];
    NSString * cmd = [NSString stringWithFormat:@"APPE %@",filePath];
    return cmd;
}

- (NSString *)storCmd {
    NSString * filePath = [self.transferItem.destURL path];
    NSString * cmd = [NSString stringWithFormat:@"STOR %@",filePath];
    return cmd;
}

- (NSString *)deleteCmd {
    NSString * filePath = [self.transferItem.destURL path];
    NSString * cmd = [NSString stringWithFormat:@"DELE %@",filePath];
    return cmd;
}

#pragma mark - Interface

- (BOOL)start {
    [self resetState];
    
    if ([self isFileExitAtPath:self.transferItem.srcURL.path]) {
        BOOL result = [self connectToFTPAndStartTransfer];
        if (result) {
            self.transferItem.transferState = [self transferingStateForTransferItem:self.transferItem];
            [self transferStateDidChangeWithError:nil];
        }else {
            self.transferItem.transferState = KLFTPTransferStateFailed;
            NSError * error = [self errorWithCode:KLFTPErrorCode_OpenError msg:@"Open Stream Error,Make sure you have the right access"];
            [self transferStateDidChangeWithError:error];
        }
        return result;
    }else {
        self.transferItem.transferState = KLFTPTransferStateFailed;
        NSError * error = [self errorWithCode:KLFTPErrorCode_LocalFileNotFound msg:@"Local File Not Found"];
        [self closeTransferStreams];
        self.transferItem.finishedSize = 0;
        [self transferStateDidChangeWithError:error];
        return NO;
    }
}

- (BOOL)pause {
    //will report state change at the socket didwritedata callback
    self.shouldPause = YES;
    return YES;
}

- (BOOL)resume {
    self.shouldPause = NO;
    [self transferRunLoop];
    self.transferItem.transferState = [self transferingStateForTransferItem:self.transferItem];
    [self transferStateDidChangeWithError:nil];
    return YES;
}

- (BOOL)stop {
    self.shouldPause = YES;
    [self sendCmd:[self deleteCmd]];
    self.transferItem.finishedSize = 0;
    self.transferItem.transferState = KLFTPTransferStateStopped;
    [self closeTransferStreams];
    [[NSFileManager defaultManager] removeItemAtPath:self.transferItem.destURL.path error:nil];
    NSError * error = [self errorWithCode:KLFTPErrorCode_ShutdownByUser msg:@"Transfer Shutdown By User"];
    [self transferStateDidChangeWithError:error];
    return YES;
}

#pragma mark - TransferLoop

- (void)transferRunLoop {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        uint8_t         buffer[32768];
        NSInteger bytesRead = [self.readStream read:buffer maxLength:sizeof(buffer)];
        if (bytesRead == -1) {
            NSError * error = [self errorWithCode:KLFTPErrorCode_LocalReadError msg:@"Local File Read Error"];
            [self transferStoppedWithError:error];
        } else if (bytesRead == 0) {
            NSError * error = [self errorWithCode:KLFTPErrorCode_NoMoreBytesForRead msg:@"No More Bytes For Read"];
            [self transferStoppedWithError:error];
        }else {
            self.bytesWritten = bytesRead;
            NSData * writeData = [NSData dataWithBytes:&buffer[0] length:bytesRead];
            [self.writeSocket writeData:writeData withTimeout:-1 tag:WRITE_TAG];
            [self.writeSocket readDataWithTimeout:-1 tag:WRITE_TAG];
        }
    });
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString * resultStr = [[NSString alloc] initWithBytes:data.bytes length:[data length] encoding:NSUTF8StringEncoding];
    FTPReturnCode retureCode = [self ftpReturnCodeWithString:resultStr];
    switch (retureCode) {
        case FTPReturnCode_ConnectionEstablished: {
            [self sendCmd:[self loginUserCmd]];
            break;
        }
        case FTPReturnCode_AskForPassword: {
            [self sendCmd:[self loginPasswordCmd]];
            break;
        }
        case FTPReturnCode_UserOnLine: {
            [self sendCmd:[self cwdCmd]];
            break;
        }
        case FTPReturnCode_CwdFinished: {
            if ([self isInDestDir]) {
                [self sendCmd:[self fileSizeCmd]];
                self.isFileSizeCmdSend = YES;
                self.shouldCreateDir = NO;
            }else {
                if (self.shouldCreateDir) {
                    self.currentPathIndex++;
                    [self sendCmd:[self createDirCmd]];
                }
            }
            break;
        }
        case FTPReturnCode_DirCreateSucceed: {
            [self sendCmd:[self cwdCmd]];
            break;
        }
        case FTPReturnCode_FileNotFound: {
            if (self.isFileSizeCmdSend) { //File not exist
                [self fileSizeDeterminedWithResultStr:resultStr returnCode:retureCode];
            }else { //CWD Failed, Dir not exist
                self.shouldCreateDir = YES;
                self.currentPathIndex--;
                [self sendCmd:[self cwdCmd]];
            }
            break;
        }
        case FTPReturnCode_FileSizeRetrived: {
            [self fileSizeDeterminedWithResultStr:resultStr returnCode:retureCode];
            break;
        }
        case FTPReturnCode_EnterPassiveMode: {
            if (self.transferItem.finishedSize > 0) {
                [self sendCmd:[self appeCmd]];
            }else {
                [self sendCmd:[self storCmd]];
            }
            NSInteger port = [self portFromFTPRetureStr:resultStr];
            if (port > 0) {
                self.pasvPort = port;
                [self prepareTransferSocketAtPort:self.pasvPort];
            }
            break;
        }
        case FTPReturnCode_ReadyToTransfer: {
            [self transferRunLoop];
            break;
        }
        default:
            break;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (tag == WRITE_TAG) {
        self.transferItem.finishedSize += self.bytesWritten;
        [self transferProgressDidChangedWithDetaSize:self.bytesWritten];
        if (self.transferItem.finishedSize < self.transferItem.fileSize) {
            if (self.shouldPause) {
                //pause
                self.transferItem.transferState = KLFTPTransferStatePaused;
                [self transferStateDidChangeWithError:nil];
            }else if (self.shouldStop) {
                NSError * error = [self errorWithCode:KLFTPErrorCode_ShutdownByUser msg:@"Transfer Shutdown By User"];
                [self transferStoppedWithError:error];
            }else {
                [self transferRunLoop];
            }
        }else {
            [self transferDidFinished];
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
}

@end
