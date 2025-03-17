# 基于shell脚本自动化检测用户登录情况

**这是一个基于shell脚本的项目，能够部署在linux系统，在检测到登录请求时进行邮件通知**

# 使用教程

## 1. 安装依赖库，完善相关配置

### 1.1 运行命令安装mailx库，用于脚本发送邮件

```bash
dnf install mailx
```
### 1.2 修改mailx库相关配置

1. 首先在Google gmail上开启两步验证
2. 接着获取应用专用密码（16位）
3. 然后在`!/etc/mail.rc`文件中加入以下配置

```bash
# !/etc/mail.rc

# ...

# gmail-set
set smtp-auth=login                             # 认证方式
set smtp-auth-user=sevenpaape832@gmail.com      # 邮箱账号
set smtp-auth-password=			        # 邮箱密码或授权码
set from="sevenpaape832@gmail.com"              # 发件人地址
set smtp=smtps://smtp.gmail.com:465             # stmp服务器地址，采用ssl协议（465端口） 
set ssl-verify=ignore                           # 忽略ssl证书验证
```

### 1.3 运行命令安装inotify-tool库

inotify-tools` 是一个用于 Linux 系统的工具包，主要用于监控文件系统的变化。它基于 Linux 内核的 `inotify` 子系统，提供了一系列命令行工具，帮助用户实时检测文件或目录的变动，并执行相应的操作

```bash
dnf install inotify-tools
```

# 2. 编写脚本文件

## 2.1 创建文件

```bash
cd /usr/local/bin
touch login-mail.sh
```

## 2.2 打开文件并编写脚本

### 脚本功能说明

1. 实时监控：通过 `inotifywait` 监听日志文件修改事件。
2. 增量日志捕获：使用 `dd` 命令精准读取新增日志内容，避免重复处理。
3. 动态字段解析：通过正则表达式和 `awk` 提取用户名、IP 地址和登录状态。
4. 防抖机制：设置 10 秒冷却时间，防止高频事件刷屏。
5. 异步邮件发送：后台执行邮件发送，避免阻塞主进程。

### 脚本代码（见login-mail.sh）

#### 关键优化说明

1. 消除自反日志刷屏 
   - 移除所有 `sudo` 命令，改用 `dd` 直接读取日志文件（在先前利用`sudo tail`命令+`while`循环读取日志，导致每次读取都会在日志中新增一条`session`记录，影响了正常登录日志的识别）
   - 必须以 root 用户运行脚本，确保有权限访问 `/var/log/secure`：
     ```bash
     sudo su
     login-mail.sh
     ```

2. 增强字段解析鲁棒性  
	- 使用 `awk` 动态提取字段
	- 示例日志格式：
	     - 成功登录：`Accepted password for user from 192.168.1.1 port 22 ssh2`  
	     - 失败登录：`Failed password for invalid user hacker from 192.168.1.2 port 22 ssh2`

3. 错误日志记录 
   - 邮件发送错误重定向至 `/var/log/mail_errors.log`，便于后续排查：
     ```bash
     tail -f /var/log/mail_errors.log
     ```

## 2.3 修改脚本运行权限

```bash
chmod +x /usr/local/bin/login-mail.sh
```
