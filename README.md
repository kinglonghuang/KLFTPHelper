KLFTPHelper
===========

##简介
KLFTPHelper是一个iOS版本的FTP传输工具，支持以下特性:<br>
*断点上传<br>
*断点下载<br>
*批任务处理<br>
*快照恢复<br>

##使用
有两种方式使用KLFTPHelper：<br>
1.只使用单个文件传输功能，使用者自己维护任务队列<br>
2.使用批任务方式<br>

方式1使用的传输类为KLFTPTransfer，它负责传输由KLFTPTransferItem定义的单个传输项目<br>
方式2使用的传输类为KLFTPHelper，它负责传输由IDFFTPTask定义的批任务(批任务包含多个item)

代码举例：

    //1.Config FTP Account
    KLFTPAccount * account = [[KLFTPAccount alloc] init];
    [account setUserName:@"FTPUserName"];
    [account setPassword:@"FTPPassword"];

    //2.Init the KLFTPTransferItem    
    KLFTPTransferItem * downloadItem = [[KLFTPTransferItem alloc] init];
    [downloadItem setSrcURL:ftpDownloadURL];
    [downloadItem setDestURL:localUrl];
    [downloadItem setFileSize:72534528]; //bytes
    [downloadItem setAccount:account];
    
    //3.Start Transfer and Receive Reports
    self.itemTransfer = [KLFTPTransfer transferWithItem:transferItem];
    [self.itemTransfer setDelegate:self];
    [self.itemTransfer start];
    
