CJ_FTP 仓颉FTP工具文档

## 类

#### - [Ftp](classes/Ftp.md) : 本库核心，FTP客户端
#### - [FtpFileItem](classes/FtpFileItem.md) : 远端文件信息

## 接口

#### - [FtpRetr](interfaces/FtpRetr.md) : 文件下载
#### - [FtpStor](interfaces/FtpStor.md) : 文件上传

## 异常

#### - FtpException \<: Exception   （FTP相关异常的共同父类）
#### - FtpConnectionException \<: FtpException    （FTP连接异常）
#### - FtpCommandException \<: FtpException    （FTP命令服务无法解析或服务器执行返回错误）
#### - FtpParseException \<: FtpException    （FTP服务器返回的内容无法解析）
