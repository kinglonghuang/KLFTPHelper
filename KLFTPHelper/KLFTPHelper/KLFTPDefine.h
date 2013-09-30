//
//  KLFTPDefine.h
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

typedef enum {
    KLFTPTransferTypeUnknown  = -1,
    KLFTPTransferTypeUpload   = 1,
    KLFTPTransferTypeDownload = 2
}KLFTPTransferType;

typedef enum {
    KLFTPTransferStateUnknown     = 1 << 0,
    KLFTPTransferStateReady       = 1 << 1,
    KLFTPTransferStatePending     = 1 << 2,
    KLFTPTransferStateUploading   = 1 << 3,
    KLFTPTransferStateDownloading = 1 << 4,
    KLFTPTransferStatePaused      = 1 << 5,
    KLFTPTransferStateStopped     = 1 << 6,
    KLFTPTransferStateFailed      = 1 << 7,
    KLFTPTransferStateFinished    = 1 << 8
}KLFTPTransferState;

typedef enum{
    KLFTPTransferStateMaskTransfering = KLFTPTransferStateUploading | KLFTPTransferStateDownloading,
    KLFTPTransferStateMaskInterrupted = KLFTPTransferStatePaused | KLFTPTransferStateStopped
}KLFTPTransferStateMask;

#define IDFFTPErrorDomain   @"KLFTPHelperErrorForiOS"

typedef enum {
    KLFTPErrorCode_OpenError = 301,
    KLFTPErrorCode_ShutdownByUser,
    KLFTPErrorCode_RemoteReadError,
    KLFTPErrorCode_RemoteWriteError,
    KLFTPErrorCode_RemoteFileNotFound,
    KLFTPErrorCode_LocalReadError,
    KLFTPErrorCode_LocalWriteError,
    KLFTPErrorCode_LocalFileNotFound,
    KLFTPErrorCode_NoMoreBytesForRead,
}IDFFTPErrorCode;