//
//  KLFTPHelper.m
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

#import "KLFTPHelper.h"
#import "KLFTPTaskTransfer.h"

#define kArchiveDataInUserDefault       @"archiveDataInUserDefault"

@interface KLFTPHelper() {
    NSMutableArray * _taskArray;
}

@property (nonatomic, assign) BOOL                  shouldContinueAfterOneTaskFinished;

@property (nonatomic, assign) BOOL                  isTaskPausedByFTPHelper;

@property (nonatomic, strong) KLFTPTaskTransfer    * taskTransfer;

- (void)takeSnapshotAndQuit;

- (void)restore;

@end

@implementation KLFTPHelper

@synthesize taskArray = _taskArray;

#pragma mark - NotificationHandler

- (void)appDidEnterBackground:(NSNotification *)noti {
    [self pauseTask:self.currentTask];
    self.isTaskPausedByFTPHelper = YES;
}

- (void)appWillEnterForeground:(NSNotification *)noti {
    if (self.isTaskPausedByFTPHelper) {
        [self resumeTask:self.currentTask];
    }
}

- (void)appWillTerminate:(NSNotification *)noti {
    [self takeSnapshotAndQuit];
}

#pragma mark - Private

- (BOOL)isCurrentTaskValid {
    return self.currentTask && self.currentTask.transferState != KLFTPTransferStateFinished;
}

- (NSInteger)indexOfTask:(KLFTPTask *)task {
    KLFTPTask * taskInPool = [self taskWithID:task.taskID];
    if (taskInPool) {
        return [self.taskArray indexOfObject:taskInPool];
    }else {
        return -1;
    }
}

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (BOOL)startTransferCurrentTask {
    BOOL canStart = self.currentTask ? (self.currentTask.transferState&(KLFTPTransferStatePending|KLFTPTransferStateReady)) : YES;
    BOOL isOnTheWay = self.currentTask.transferState & KLFTPTransferStateMaskTransfering;
    if (isOnTheWay || !canStart) {
        //If transfer is on the way, just return okay
        //We don't transfer the task which has been paused, stopped or transfer on the way, just report okay
        return YES;
    }
    
    if (!self.taskTransfer) {
        self.taskTransfer = [[KLFTPTaskTransfer alloc] init];
    }
    [self.taskTransfer setDelegate:self];
    
    if (!self.currentTask && self.taskArray.count) {
        self.currentTask = [self.taskArray objectAtIndex:0];
    }
    
    [self.taskTransfer setTask:self.currentTask];
    return [self.taskTransfer start];
}

- (void)startTransferNextTaskAfterIndex:(NSInteger)index setNilIfNotFound:(BOOL)shouldSetNil {
    if (self.shouldContinueAfterOneTaskFinished) {
        //check whether there are pending tasks
        for (KLFTPTask * task in _taskArray) {
            if (task.transferState == KLFTPTransferStatePending) {
                [self setCurrentTask:task];
                [self startTransferCurrentTask];
                return;
            }
        }
        //if no pending, start next;
        index++;
        if (index < [self.taskArray count] && self.shouldContinueAfterOneTaskFinished) {
            [self setCurrentTask:[self.taskArray objectAtIndex:index]];
            [self startTransferCurrentTask];
        }else {
            //All Task Finished
            if (shouldSetNil) {
                self.currentTask = nil;
            }
        }
    }else {
        //check whether there are pending tasks
        for (KLFTPTask * task in _taskArray) {
            if (task.transferState == KLFTPTransferStatePending) {
                [self setCurrentTask:task];
                [self startTransferCurrentTask];
                return;
            }
        }
        
        //if there is no pending
        if (shouldSetNil) {
            [self setCurrentTask:nil];
        }
    }
}

- (void)moveTaskToEndOfTaskArray:(KLFTPTask *)task {
    NSInteger index = [self indexOfTask:task];
    for (int i = index; i < _taskArray.count-1; i ++) {
        [_taskArray exchangeObjectAtIndex:i withObjectAtIndex:(i+1)];
    }
}

- (void)pendingTask:(KLFTPTask *)task {
    [self moveTaskToEndOfTaskArray:task];
    KLFTPTask * taskInPool = [self taskWithID:task.taskID];
    [taskInPool setTransferState:KLFTPTransferStatePending];
    [self taskTransfer:self.taskTransfer transferStateDidChangedForTask:task error:nil];
}

#pragma mark - Singleton

+ (KLFTPHelper *)sharedHelper {
    static dispatch_once_t pred = 0;
    static KLFTPHelper * _sharedHelper = nil;
    dispatch_once(&pred, ^{
        _sharedHelper = [[self alloc] init];
        [_sharedHelper setShouldContinueAfterOneTaskFinished:NO];
        [_sharedHelper addNotificationObserver];
        [_sharedHelper restore];
    });
    return _sharedHelper;
}

#pragma mark - Task Operation

- (BOOL)addFTPTask:(KLFTPTask *)task {    
    if (!_taskArray) {
        _taskArray = [NSMutableArray arrayWithCapacity:0];
    }
    task.transferState = KLFTPTransferStateReady;
    
    KLFTPTask * taskInPool = [self taskWithID:task.taskID];
    if (!taskInPool) {
        [_taskArray addObject:task];
    }
    
    return YES;
}

- (BOOL)removeFTPTask:(KLFTPTask *)task {
    KLFTPTask * taskInPool = [self taskWithID:task.taskID];
    NSMutableArray * tempArray = [NSMutableArray arrayWithArray:self.taskArray];
    if (taskInPool) {
        taskInPool.transferState = KLFTPTransferStateUnknown;
        [tempArray removeObject:taskInPool];
        _taskArray = [NSMutableArray arrayWithArray:tempArray];
    }
    return YES;
}

- (BOOL)startTask:(KLFTPTask *)task {
    if (!task) {
        self.shouldContinueAfterOneTaskFinished = YES;//Start All can Start
        [self startTransferCurrentTask];
        return YES;
    }else {
        if (self.currentTask.transferState & KLFTPTransferStateMaskTransfering) {
            if ([self.currentTask.taskID isEqualToString:task.taskID]) {
                return YES;
            }else {
                [self pendingTask:task];
                return YES;
            }
        }else {
            [task setTransferState:KLFTPTransferStateReady];
            [self setCurrentTask:task];
            BOOL result = [self startTransferCurrentTask];
            return result;
        }
    }
    return YES;
}

- (BOOL)stopTask:(KLFTPTask *)task {
    KLFTPTask * taskInPool = [self taskWithID:task.taskID];
    
    if (!taskInPool) {
        BOOL result = [self.taskTransfer stop];
        [self startTransferNextTaskAfterIndex:[self indexOfTask:self.currentTask] setNilIfNotFound:YES];
        return result;
    }else {
        if ([self.currentTask.taskID isEqualToString:task.taskID]) {
            BOOL result = [self.taskTransfer stop];
            [self startTransferNextTaskAfterIndex:[self indexOfTask:self.currentTask] setNilIfNotFound:YES];
            return result;
        }else {
            [taskInPool setTransferState:KLFTPTransferStateStopped];
            [taskInPool setFinishedSize:0];
            [taskInPool setCurrentItemIndex:0];
            [self taskTransfer:self.taskTransfer transferStateDidChangedForTask:taskInPool error:nil];
            return YES;
        }
    }
    
    return YES;
}

- (BOOL)pauseTask:(KLFTPTask *)task {
    if (task) {
        KLFTPTask * taskInPool = [self taskWithID:task.taskID];
        if ([self.currentTask.taskID isEqualToString:taskInPool.taskID]) {
            if (taskInPool.transferState & KLFTPTransferStateMaskTransfering) {
                BOOL result = [self.taskTransfer pause];
                if (result) {
                    [self startTransferNextTaskAfterIndex:[self indexOfTask:taskInPool] setNilIfNotFound:NO];
                }
                return result;
            }
            return NO;
        }else {
            [taskInPool setTransferState:KLFTPTransferStatePaused];
            [self taskTransfer:self.taskTransfer transferStateDidChangedForTask:taskInPool error:nil];
            return YES;
        }
    }else {
        return [self.taskTransfer pause];
    }
}

- (BOOL)resumeTask:(KLFTPTask *)task {
    if (task) {
        KLFTPTask * taskInPool = [self taskWithID:task.taskID];
        if ([self.currentTask.taskID isEqualToString:taskInPool.taskID]) {
            if (taskInPool.transferState == KLFTPTransferStatePaused) {
                return [self.taskTransfer resume];
            }
            return NO;
        }else if (self.currentTask.transferState & KLFTPTransferStateMaskTransfering) {
            [self pendingTask:taskInPool];
            return YES;
        }else {
            [task setTransferState:KLFTPTransferStateReady];
            [self setCurrentTask:task];
            BOOL result = [self startTransferCurrentTask];
            return result;
        }
    }else {
        return [self.taskTransfer resume];
    }
}

#pragma mark - Serialization

- (void)takeSnapshotAndQuit {
    [self.taskTransfer pause];
    NSData * taskArrayData = [NSKeyedArchiver archivedDataWithRootObject:self.taskArray];
    [[NSUserDefaults standardUserDefaults] setObject:taskArrayData forKey:kArchiveDataInUserDefault];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)restore {
    NSData * taskArrayData = [[NSUserDefaults standardUserDefaults] objectForKey:kArchiveDataInUserDefault];
    if (taskArrayData) {
        NSArray * taskArray = (NSArray *)[NSKeyedUnarchiver unarchiveObjectWithData:taskArrayData];
        if ([taskArray isKindOfClass:[NSArray class]] && [taskArray count]) {
            _taskArray = [taskArray mutableCopy];
            
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kArchiveDataInUserDefault];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

#pragma mark - Helper

- (KLFTPTask *)taskWithID:(NSString *)taskID {
    for (KLFTPTask * task in self.taskArray) {
        if ([task.taskID isEqualToString:taskID]) {
            return task;
        }
    }
    return nil;
}

#pragma mark - TaskTransferDelegate

- (void)taskTransfer:(KLFTPTaskTransfer *)taskTransfer progressChangedForTask:(KLFTPTask *)task {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(klFTPHelpder:progressChangedForTask:)]) {
            [self.delegate klFTPHelpder:self progressChangedForTask:task];
        }
    });
}

- (void)taskTransfer:(KLFTPTaskTransfer *)taskTransfer transferStateDidChangedForTask:(KLFTPTask *)task error:(NSError *)error {
    if (task.transferState == KLFTPTransferStateFinished) {
        NSInteger index = [self indexOfTask:task];
        [self startTransferNextTaskAfterIndex:index setNilIfNotFound:YES];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(klFTPHelpder:transferStateDidChangedForTask:error:)]) {
            [self.delegate klFTPHelpder:self transferStateDidChangedForTask:task error:error];
        }
    });
}

@end
