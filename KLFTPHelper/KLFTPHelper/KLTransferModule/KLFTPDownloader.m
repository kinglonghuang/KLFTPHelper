//
//  KLFTPDownloader.m
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

#import "KLFTPDownloader.h"

@interface KLFTPDownloader()

@property (nonatomic, strong) NSInputStream         * readStream;

@property (nonatomic, strong) NSOutputStream        * writeStream;

@property (nonatomic, assign) dispatch_queue_t      currentQueue;

@property (nonatomic, strong) NSRunLoop             * downloadRunLoop;

@end

@implementation KLFTPDownloader

#pragma mark - Private

- (NSError *)errorWithCode:(IDFFTPErrorCode)errorCode msg:(NSString *)msg {
    msg = [msg length] ? msg : @"";
    NSDictionary * errorInfo = [NSDictionary dictionaryWithObject:msg forKey:@"errorMsg"];
    NSError * error = [[NSError alloc] initWithDomain:IDFFTPErrorDomain code:errorCode userInfo:errorInfo];
    return error;
}

- (NSURL *)smartURLForString:(NSString *)str
{
    NSURL *     result;
    NSString *  trimmedStr;
    NSRange     schemeMarkerRange;
    NSString *  scheme;
    
    assert(str != nil);
    
    result = nil;
    
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && ([trimmedStr length] != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            result = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"ftp"  options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedStr];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
    
    return result;
}

- (BOOL)initAndOpenStream {
    [self closeTransferStreams];
    
    self.readStream = CFBridgingRelease(CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) self.transferItem.srcURL));
    [self.readStream setProperty:[NSNumber numberWithUnsignedLongLong:self.transferItem.finishedSize] forKey:(id)kCFStreamPropertyFTPFileTransferOffset];
    [self.readStream setProperty:[NSNumber numberWithBool:YES] forKey:(id)kCFStreamPropertyFTPFetchResourceInfo];
    BOOL result = [self.readStream setProperty:self.transferItem.account.userName forKey:(id)kCFStreamPropertyFTPUserName];
    result = [self.readStream setProperty:self.transferItem.account.password forKey:(id)kCFStreamPropertyFTPPassword];
    
    if (self.readStream) {
        dispatch_async(self.currentQueue, ^{
            [self.readStream open];
        });
        return YES;
    }
    return NO;
}

- (KLFTPTransferState)transferingStateForTransferItem:(KLFTPTransferItem *)item {
    KLFTPTransferState state = (self.transferItem.transferType == KLFTPTransferTypeUpload) ? KLFTPTransferStateUploading : KLFTPTransferStateDownloading;
    return state;
}

- (void)startTransfer {
    dispatch_async(self.currentQueue, ^{
        [self.readStream setDelegate:self];
        self.downloadRunLoop = [NSRunLoop currentRunLoop];
        [self.readStream scheduleInRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
        [self.downloadRunLoop runUntilDate:[NSDate distantFuture]];
    });
}

- (void)closeTransferStreams {
    if (self.readStream) {
        [self.readStream close];
        [self.readStream setDelegate:nil];
        if (self.downloadRunLoop) {
            [self.readStream removeFromRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
        }
        self.readStream = nil;
    }
    if (self.writeStream) {
        [self.writeStream close];
        if (self.downloadRunLoop) {
            [self.writeStream removeFromRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
        }
        self.writeStream = nil;
    }
    
    self.downloadRunLoop = nil;
}

- (void)transferStoppedWithError:(NSError *)error {
    [self closeTransferStreams];
    self.transferItem.finishedSize = 0;
    self.transferItem.transferState = error ? KLFTPTransferStateFailed : KLFTPTransferStateStopped;
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

- (uint64_t)fileSizeAtPath:(NSString *)filePath {
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSDictionary  * dict = [fileManager attributesOfItemAtPath:filePath error:nil];
	return [dict fileSize];
}

#pragma mark - LifeCycle

- (id)init {
    self = [super init];
    if (self) {
        return self;
    }
    return nil;
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
    if (self.transferItem.transferState != KLFTPTransferStateFinished) {
        [self closeTransferStreams];
        self.transferItem.transferState = KLFTPTransferStateFinished;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(klFTPTransfer:transferStateDidChangedForItem:error:)]) {
                [self.delegate klFTPTransfer:self transferStateDidChangedForItem:self.transferItem error:nil];
            }
        });

    }
}

#pragma mark - Interface

- (BOOL)start {
    self.currentQueue = dispatch_queue_create("DownloadQueue", NULL);
    BOOL streamReady = [self initAndOpenStream];
    if (streamReady) {
        [self startTransfer];
        self.transferItem.transferState = [self transferingStateForTransferItem:self.transferItem];
        [self transferStateDidChangeWithError:nil];
        return YES;
    }
    return NO;
}

- (BOOL)pause {
    if (self.transferItem.transferState & KLFTPTransferStateMaskTransfering) {
        [self.readStream setDelegate:nil];
        if (self.downloadRunLoop) {
            [self.readStream removeFromRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
        }
        self.transferItem.transferState = KLFTPTransferStatePaused;
        [self transferStateDidChangeWithError:nil];
    }
    return YES;
}

- (BOOL)resume {
    if (self.transferItem.transferState == KLFTPTransferStatePaused) {
        if (self.downloadRunLoop) {
            [self.readStream setDelegate:self];
            [self.readStream scheduleInRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
            self.transferItem.transferState = [self transferingStateForTransferItem:self.transferItem];
            [self transferStateDidChangeWithError:nil];
        }
    }
    return YES;
}

- (BOOL)stop {
    NSError * error = [self errorWithCode:KLFTPErrorCode_ShutdownByUser msg:@"Transfer Shutdown By User"];
    [self closeTransferStreams];
    self.transferItem.finishedSize = 0;
    self.transferItem.transferState = KLFTPTransferStateStopped;
    [[NSFileManager defaultManager] removeItemAtPath:self.transferItem.destURL.path error:nil];
    [self transferStateDidChangeWithError:error];
    return YES;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            uint64_t sizeReportedFromServer = [[self.readStream propertyForKey:(id)kCFStreamPropertyFTPResourceSize] unsignedLongLongValue];
            
            //update the file size from server to make sure the file size is uptodate
            if (sizeReportedFromServer > 0) {
                self.transferItem.fileSize = sizeReportedFromServer;
            }
            
            //read the local file to update the finished file size
            uint64_t localFileSize = [self fileSizeAtPath:self.transferItem.destURL.path];
            self.transferItem.finishedSize = localFileSize;
            
            //offset setup and stream open
            if (self.transferItem.finishedSize >= self.transferItem.fileSize) {
                [self transferProgressDidChangedWithDetaSize:self.transferItem.finishedSize];
                [self transferDidFinished];
                break;
            }else if (self.transferItem.fileSize > [self fileSizeAtPath:[self.transferItem.destURL path]]){
                self.writeStream = [NSOutputStream outputStreamToFileAtPath:[self.transferItem.destURL path] append:YES];
                [self.writeStream setProperty:[NSNumber numberWithUnsignedLongLong:self.transferItem.finishedSize] forKey:(id)kCFStreamPropertyFTPFileTransferOffset];
            } else {
                self.writeStream = [NSOutputStream outputStreamToFileAtPath:[self.transferItem.destURL path] append:NO];
            }
            
            [self.writeStream open];
            if (self.downloadRunLoop) {
                [self.writeStream scheduleInRunLoop:self.downloadRunLoop forMode:NSDefaultRunLoopMode];
            }
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];
            
            bytesRead = [self.readStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                NSError * error = [self errorWithCode:KLFTPErrorCode_RemoteReadError msg:@"Remote File Read Error"];
                [self transferStoppedWithError:error];
            } else if (bytesRead == 0) {
                NSError * error = [self errorWithCode:KLFTPErrorCode_NoMoreBytesForRead msg:@"No More Bytes For Read"];
                [self transferStoppedWithError:error];
            } else {
                // Write to the file.
                NSInteger   bytesWritten;
                NSInteger   bytesWrittenSoFar;
                bytesWrittenSoFar = 0;
                do {
                    bytesWritten = [self.writeStream write:&buffer[bytesWrittenSoFar] maxLength:(NSUInteger) (bytesRead - bytesWrittenSoFar)];
                    if (bytesWritten == -1) {
                        NSError * error = [self errorWithCode:KLFTPErrorCode_LocalWriteError msg:@"Local File Write Error"];
                        [self transferStoppedWithError:error];
                        break;
                    } else {
                        bytesWrittenSoFar += bytesWritten;
                    }
                } while (bytesWrittenSoFar != bytesRead);
                self.transferItem.finishedSize += bytesWrittenSoFar;
                
                [self transferProgressDidChangedWithDetaSize:bytesWrittenSoFar];
                
                if (self.transferItem.finishedSize >= self.transferItem.fileSize) {
                    [self transferDidFinished];
                }
            }
            break;
        } 
        case NSStreamEventHasSpaceAvailable: {
            break;
        } 
        case NSStreamEventErrorOccurred: {
            NSError * error = [self errorWithCode:KLFTPErrorCode_OpenError msg:@"Open Stream Error,Make sure you have the right access"];
            [self transferStoppedWithError:error];
            break;
        }
        case NSStreamEventEndEncountered: {
            // ignore
            break;
        }
        default: {
            assert(NO);
            break;
        }
    }
}

@end
