interface FtpStor 文件上传
=========================

## 成员函数

| 函数 | 说明 |
| :-- | :-- |
| onStorStart | 开始上传文件时调用
| onStorEnd | 开始上传完成时调用
| onStorException(Exception) | 文件上传发生异常时调用
| onStorRead(data: Array<UInt8>): Int64 | 文件读取

## 已知实现

[FtpStorFile](../classes/StorAndStor.md#FtpStorFile)
[FtpStorStream](../classes/StorAndStor.md#FtpStorStream)

