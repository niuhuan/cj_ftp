interface FtpRetr 文件下载
=========================

## 成员函数

| 函数 | 说明 |
| :-- | :-- |
| onRetrStart | 开始下载文件时调用
| onRetrEnd | 开始下载完成时调用
| onRetrException(Exception) | 文件下载发生异常时调用
| onRetrWrite(Array<UInt8>) | 文件写入

## 已知实现

[FtpRetrFile](../classes/RetrAndStor.md#FtpRetrFile)
[FtpRetrStream](../classes/RetrAndStor.md#FtpRetrStream)

