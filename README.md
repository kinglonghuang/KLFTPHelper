KLFTPHelper
===========

##简介
KLFTPHelper是一个iOS版本的FTP传输工具，支持以下特性：
1.断点上传
2.断点下载
3.批任务处理
4.快照恢复

##使用
有两种方式使用KLFTPHelper：
1.只使用单个文件传输功能，使用者自己维护任务队列
2.使用批任务方式

方式1使用的传输类为KLFTPTransfer，它负责传输由KLFTPTransferItem定义的单个传输项目
方式2使用的传输类为KLFTPHelper，它负责传输由IDFFTPTask定义的批任务(批任务包含多个item)

代码举例：
    //Set FTP Account Info
    KLFTPAccount * account = [[KLFTPAccount alloc] init];
    [account setUserName:@"FTPUserName"];
    [account setPassword:@"FTPPassword"];

    //Init the KLFTPTransferItem    
    NSString * downloadURLStr = @"ftp://10.10.92.99/item1.dmg";
    downloadURLStr = [downloadURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL * ftpDownloadURL = [NSURL URLWithString:downloadURLStr];
    NSURL *  localUrl = [self localFileURLForRemoteFileName:[ftpDownloadURL lastPathComponent]];
    KLFTPTransferItem * downloadItem = [[KLFTPTransferItem alloc] init];
    [downloadItem setSrcURL:ftpDownloadURL];
    [downloadItem setDestURL:localUrl];
    [downloadItem setFileSize:72534528];
    [downloadItem setAccount:account];
