KLFTPHelper
===========

##简介
KLFTPHelper是一个iOS版本的FTP传输工具，支持以下特性:<br>
1.断点上传<br>
2.断点下载<br>
3.批任务<br>
4.快照恢复<br>

##使用
有两种方式使用KLFTPHelper：<br>
* 使用单个文件传输功能<br>
调用者自己维护任务队列，传输类为KLFTPTransfer,它负责传输由KLFTPTransferItem定义的单个传输项目<br>
* 使用批任务<br>
传输类为KLFTPHelper，它负责传输由IDFFTPTask定义的批任务(批任务包含多个item)

##示例
####使用单个文件传输

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
    
####单个文件传输回调
    //当传输状态发生改变时(开始，暂停，停止，完成...)的代理方法
    - (void)klFTPTransfer:(KLFTPTransfer *)transfer transferStateDidChangedForItem:(KLFTPTransferItem *)item error:(NSError *)error

    //传输进度发生改变时的回调
    - (void)klFTPTransfer:(KLFTPTransfer *)transfer progressChangedForItem:(KLFTPTransferItem *)item

##静态库
建议将KLFTPHelper打包成静态库libKLFTPHelper.a使用，在终端运行build.sh脚本即可在工程目录下生成IDFFTPHelper_Release文件夹，其中包含arm,i386以及universal版本
(如果提示权限不够，可使用命令： chmod 755 /path/to/build.sh)
