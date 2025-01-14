class FtpListItem FTP服务器中的文件信息
====================================

| 变量 | 类型 | 说明 |
| :-- | :-- | :-- |
| perms | String | 文件权限信息 (若第一位是`-`则为文件，若第一位是`d`则是文件夹) | 
| nlink | Int64 | 硬连接数量 |
| user | String | 文件用户(id) | 
| group | String | 文件用户组(id) | 
| size | Int64 | 文件尺寸 | 
| month | String | 文件变更时间 | 
| day | String | 文件变更时间 | 
| time | String | 年 ( 2024 ) 或者 时:分 ( 12:25 ) | 
| name | String | 文件名称 | 
