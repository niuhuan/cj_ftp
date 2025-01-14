CJ_FTP 仓颉FTP工具
=================

仓颉编程语言实现的 FTP 基础工具库, 支持TLS以及被动模式

## 💡 设计

- 简单易用代码量较少的FTP工具包

## 📦 安装

1.&nbsp;使用git方式进行引入, 将依赖放入`cjpm.toml`

```yaml
[dependencies]

cj_ftp = { git = "https://gitcode.com/niuhuan_cn/cj_ftp.git" }
```

2.&nbsp;执行 `cjpm update` 命令进行依赖更新 

3.&nbsp;在需要使用的仓颉代码中进行引入`import cj_ftp.*`

4.&nbsp;后续更新需要再次执行`cjpm update`进行代码拉取。当仓颉包管理器完善时，本项目将尽快会推送到仓库, 使用版本依赖使用

## 🔖 用例

更多使用方法请参考[API文档](/docs/api_doc.md)

```cangjie
import cj_ftp.*

main(): Int64 {
    try (ftp = Ftp(host, port)) {
        ftp.tryIntoSecure()
        ftp.login(username, password)
        let pwd = ftp.pwd()
        ftp.cwd("dir")
        ftp.mkd("dir")
        ftp.rmd("dir")
        ftp.stor("image.png", FtpStorFile("image.png"))
        ftp.retr("image.png", FtpRetrFile("downlaods/image.png"))
        ftp.move("image.png", "image.bak")
        ftp.dele("image.bak")
        let items = ftp.mlsd()
        ftp.quit()
    }
    0
}
```

## 📖 特性

- [x] FTP
    - [x] `FEAT` 功能列表
    - [x] `OPTS`/`MODE`/`TYPE` 协议设置
    - [x] `USER`/`PASS` 登录
    - [x] `AUTH` TLS
    - [x] `PROT` 保护级别
    - [x] `PWD`/`XPWD`/`CWD` (切换)工作目录
    - [x] `PASV`/`EPSV` 被动模式
    - [x] `MLSD`/`LIST` 列表
    - [x] `RERT`/`STOR`/`DELE`/`APPE`/`STOU` 上传下载删除续传文件
    - [x] `RNFR`/`RNTO` 移动文件
    - [x] `NOOP`/`SYST`/`QUIT`

| 参考外部链接 | 说明
| -- | :-- |
| [RFC697](https://tools.ietf.org/html/rfc697) |  CWD Command of FTP |
| [RFC959](https://tools.ietf.org/html/rfc959) |  File Transfer Protocol (FTP) |
| [RFC1639](https://tools.ietf.org/html/rfc1639) |  FTP Operation Over Big Address Records (FOOBAR) |
| [RFC2228](https://tools.ietf.org/html/rfc2228) |  FTP Security Extensions |
| [RFC2389](https://tools.ietf.org/html/rfc2389) |  Feature negotiation mechanism for the File Transfer Protocol |
| [RFC2428](https://tools.ietf.org/html/rfc2428) |  FTP Extensions for IPv6 and NATs |
| [RFC2640](https://tools.ietf.org/html/rfc2640) |  Internationalization of the File Transfer Protocol |
| [RFC3659](https://tools.ietf.org/html/rfc3659) |  Extensions to FTP |
| [RFC5797](https://tools.ietf.org/html/rfc5797) |  FTP Command and Extension Registry |

## 🏗️ 构建

### 经过验证的仓颉版本

| 版本 | 分支 | 
| -- | -- |
| 0.53.13 | main |
| 0.57.3 | main |

### 单元测试
`cjpm test -V src/tests`

## 🏆 贡献

欢迎您的issue或pull request到仓颉TCP或上游仓库地址

fork时请保留上游仓库地址 [https://gitcode.com/niuhuan_cn/cj_ftp](https://gitcode.com/niuhuan_cn/cj_ftp)

## 📕 协议

参考 [LICENSE](LICENSE) 文件

