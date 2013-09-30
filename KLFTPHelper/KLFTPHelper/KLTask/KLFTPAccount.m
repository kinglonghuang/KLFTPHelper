//
//  KLFTPAccount.m
//  TestKLFTPHelper
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

#import <CommonCrypto/CommonCrypto.h>
#import "KLFTPAccount.h"

#define kUserName       @"userName"
#define kPwd            @"password"

@implementation KLFTPAccount

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.userName forKey:kUserName];
    NSData * pwdData = [NSData dataWithBytes:[self.password UTF8String] length:self.password.length];
    NSData * encryptData = [self AES256EncryptForData:pwdData withKey:@"KLFTPHelper_BY_KINGLONG_HUANG"];
    [encoder encodeObject:encryptData forKey:kPwd];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.userName = [aDecoder decodeObjectForKey:kUserName];
        NSData * encryotData = [aDecoder decodeObjectForKey:kPwd];
        NSData * decryptData = [self AES256DecryptForData:encryotData withKey:@"KLFTPHelper_BY_KINGLONG_HUANG"];
        self.password = [[NSString alloc] initWithData:decryptData encoding:NSUTF8StringEncoding];
        return self;
    }
    return nil;
}

#pragma mark - AES256

- (NSData *)AES256EncryptForData:(NSData *)plainData withKey:(NSString *)key  {
    char keyPtr[kCCKeySizeAES256 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [plainData length];
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesEncrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL ,
                                          [plainData bytes], dataLength, 
                                          buffer, bufferSize, 
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

- (NSData *)AES256DecryptForData:(NSData *)aesData withKey:(NSString *)key {
    char keyPtr[kCCKeySizeAES256 + 1]; 
    bzero(keyPtr, sizeof(keyPtr)); 
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [aesData length];
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesDecrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL ,
                                          [aesData bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

@end
