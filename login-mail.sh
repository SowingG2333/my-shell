#!/bin/bash

# ----------------- 配置部分 -----------------
# 邮件接收地址
EMAIL_TO="3243856409@qq.com"
# 监控的日志文件路径
LOG_FILE="/var/log/secure"

# ----------------- 初始化部分 -----------------
# 获取初始日志文件大小
LAST_SIZE=$(wc -c < "$LOG_FILE")
# 设置防抖冷却时间，防止频繁发送邮件
COOLDOWN=10
LAST_EVENT_TIME=0

# ----------------- 监控主循环 -----------------
inotifywait -m -e modify --format "%e %f" "$LOG_FILE" | while read -r event file; do
    # 防抖处理：10 秒内仅处理一次事件
    current_time=$(date +%s)
    if (( current_time - LAST_EVENT_TIME < COOLDOWN )); then
        echo "[$(date)] 事件冷却中，跳过处理"
        continue
    fi
    LAST_EVENT_TIME=$current_time

    # 计算新增日志内容大小
    CURRENT_SIZE=$(wc -c < "$LOG_FILE")
    NEW_BYTES=$((CURRENT_SIZE - LAST_SIZE))
    
    # 捕获新增日志（使用dd命令代替sudo tail）
    NEW_LOG=$(dd if="$LOG_FILE" bs=1 skip="$LAST_SIZE" count="$NEW_BYTES" 2>/dev/null)
    LAST_SIZE=$CURRENT_SIZE  # 更新日志指针

    # ----------------- 日志解析 -----------------
    echo "$NEW_LOG" | while IFS= read -r line; do
        USER=""
        IP=""
        STATUS=""

        # 成功登录匹配
        if [[ "$line" =~ "Accepted password for " ]]; then
            USER=$(awk '{print $9}' <<< "$line")   # 用户名在第9列
            IP=$(awk '{print $11}' <<< "$line")    # IP地址在第11列
            STATUS="成功"
        
        # 失败登录匹配
        elif [[ "$line" =~ "Failed password for " ]]; then
            if grep -q "invalid user" <<< "$line"; then
                USER=$(awk '{print $11}' <<< "$line")  # 无效用户场景
            else
                USER=$(awk '{print $9}' <<< "$line")   # 有效用户但密码错误
            fi
            IP=$(awk '{print $11}')
            STATUS="失败"
        else
            continue  # 忽略非登录事件
        fi

        # ----------------- 邮件通知 -----------------
        SUBJECT="【安全告警】用户$USER 登录$STATUS"
        BODY="用户: $USER\n登录状态: $STATUS\n来源IP: $IP\n时间: $date"
        
        # 异步发送邮件（后台执行）
        (
            echo -e "$BODY" | mailx -s "$SUBJECT"\
                "$EMAIL_TO" 2>> /var/log/mail_errors.log
        ) &
    done
done