class Ftp
=========

## 用例
```cangjie
import cj_ftp.*

main(): Int64 {
    try (ftp = Ftp(host，port)) {
        ftp.tryIntoSecure()
        ftp.login(username，password)
        let pwd = ftp.pwd()
        ftp.cwd("dir")
        ftp.mkd("dir")
        ftp.rmd("dir")
        ftp.stor("image.png"，FtpStorFile("image.png"))
        ftp.retr("image.png"，FtpRetrFile("downlaods/image.png"))
        ftp.move("image.png"，"image.bak")
        ftp.dele("image.bak")
        let items = ftp.mlsd()
        ftp.quit()
    }
    0
}
```

## 实现父类或接口

- Resource

## 构造器
| 函数 | 说明 |
| -- | :-- |
| init(host: String，port: UInt16) | 创建一个FTP链接实例
| init(socket: StreamingSocket，host: String) | 同上，但使用自定义链接传输

## 属性
| 属性 | 说明 |
| :-- | :-- |
| get features: ArrayList<String> | 此FTP支持哪些拓展
| get tls: Bool | 当前是否启用了tls/ssl

## 成员函数
| 函数 | 说明 | 参数说明 |
| :-- | :-- | :-- | 
| tryIntoSecure | 尝试进入tls/ssl传输模式，若成功返回true，失败则返回false
| login | 进行用户身份验证
| pwd | 执行`PWD`命令，返回当前所在文件夹
| xpwd | 执行`XPWD`命令，返回当前所在文件夹
| cwd | 执行`cwd`命令，更换当前所在目录 | 
| mlsd | 执行`MLSD`命令，列出文件夹中的文件，返回ArrayList<[FtpFileItem](./FtpFileItem.md)>
| retr | 执行`RETR`命令，并下载文件 | String 服务器中文件路径，[FtpRetr](../interfaces/FtpRetr.md) 下载监听器 / OutputStream 将文件下载到输出流
| stor | 执行`STOR`命令，进行文件上传 | String 服务器中的文件路径，[FtpStor](../interfaces/FtpStor.md) 下载监听器 / InputStream 从输入流读取文件
| appe | 执行`APPE`命令，进行文件追加 | 同`stor`
| stou | 执行`STOU`命令，进行文件覆盖 | 同`stor`
| mkd | 执行 `MKD`命令，创建文件夹
| rmd | 执行`RMD`命令，删除文件夹（注意，只能删除非空文件夹
| dele | 执行`DELE`命令，删除文件
| move | 移动/重命名文件或文件夹
| quit | 执行`QUIT` 退出FTP
| noop | 执行`NOOP`，无实际操作的命令，可用于检测链接是否正常的命令
| feat | 执行`FEAT`命令，并返回此FTP可以使用的拓展
| user | 执行`USER`命令，用户登录（建议使用login代替
| pass | 执行`PASS`命令，用户登录（建议使用login代替
| rnfr | 执行`RNFR`命令，此命令意为重命名/移动剪切（RENAME FROM），建议使用`move`代替
| rnto | 执行`RNTO`命令，此命令意为重命名/移动粘贴（RENAME TO），建议使用`move`代替
| opts | 执行`OPTS`命令，用于修改此链接的属性 （不建议手动调用，传输文件前会自动设置相应参数
| mode | 执行`MODE`命令，用于修改此链接的传输模式 （不建议手动调用，传输文件前会自动设置相应参数
| ftpType | 执行`TYPE`命令，用于修改此链接的类型 （不建议手动调用，传输文件前会自动设置相应参数
| prot | 执行`PROT`命令，用于修改此链接的安全等级 （不建议手动调用，传输文件前会自动设置相应参数


## 覆盖父类或接口的函数

- close
- isClosed
