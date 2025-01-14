class FtpMlsdItem FTP服务器中的文件信息
====================================

| 变量 | 类型 | 说明 |
| :-- | :-- | :-- |
| itemType | String | 枚举 cdir pdir dir file ，cdir: 当前文件夹`.`，pdir: 父文件夹`..` |
| size | Int64 | 文件尺寸 | 
| modify | Float64 | 文件变更时间 | 
| unixUid | Int64 | 文件用户id | 
| unixGid | Int64 | 文件用户组id | 
| unique | String | 文件唯一id | 
| perms | String | 文件权限信息（有可能为空字符串 | 
| name | String | 文件名称 | 
