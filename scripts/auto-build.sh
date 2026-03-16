#!/bin/bash

# 自动构建和监控脚本
# 用于自动重试构建直到成功

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
MAX_ATTEMPTS=10
WAIT_BETWEEN_ATTEMPTS=30  # 秒
MONITOR_INTERVAL=15  # 秒
WORKFLOW_NAME="Deploy to CloudBase"
REPO_PATH=$(pwd)

echo -e "${BLUE}🔧 Auto Build and Monitor Script${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Repository: $REPO_PATH"
echo "Workflow: $WORKFLOW_NAME"
echo "Max attempts: $MAX_ATTEMPTS"
echo ""

# 检查git状态
echo -e "${YELLOW}📋 Checking git status...${NC}"
git status
echo ""

# 检查是否所有更改都已提交
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  There are uncommitted changes.${NC}"
    read -p "Do you want to commit changes before building? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}📝 Committing changes...${NC}"
        git add .
        git commit -m "Auto-build: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
fi

# 推送到远程仓库
echo -e "${YELLOW}🚀 Pushing to remote repository...${NC}"
git push origin main || {
    echo -e "${RED}❌ Failed to push to remote${NC}"
    exit 1
}

echo -e "${GREEN}✅ Successfully pushed to remote${NC}"
echo ""

# 触发GitHub Actions构建的函数
trigger_build() {
    echo -e "${YELLOW}🎯 Triggering GitHub Actions build...${NC}"
    
    # 使用GitHub CLI触发工作流
    if command -v gh &> /dev/null; then
        gh workflow run "$WORKFLOW_NAME" --ref main
        echo -e "${GREEN}✅ Workflow triggered via GitHub CLI${NC}"
    else
        # 如果没有GitHub CLI，依靠git push自动触发
        echo -e "${YELLOW}⚠️  GitHub CLI not found. Relying on git push to trigger workflow.${NC}"
        echo -e "${YELLOW}Waiting for workflow to start automatically...${NC}"
    fi
}

# 获取最新工作流运行状态的函数
get_latest_workflow_status() {
    if command -v gh &> /dev/null; then
        gh run list --workflow "$WORKFLOW_NAME" --limit 1 --json status,conclusion,url,createdAt
    else
        echo "{\"status\":\"unknown\",\"conclusion\":\"unknown\",\"url\":\"\",\"createdAt\":\"\"}"
    fi
}

# 显示工作流状态
show_workflow_status() {
    local status=$1
    local conclusion=$2
    local url=$3
    
    echo -e "${BLUE}📊 Current Workflow Status:${NC}"
    echo "  Status: $status"
    echo "  Conclusion: $conclusion"
    
    if [ -n "$url" ]; then
        echo "  URL: $url"
    fi
    
    echo ""
}

# 主要构建和监控循环
attempt=1
build_success=false

while [ $attempt -le $MAX_ATTEMPTS ] && [ "$build_success" = false ]; do
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}🔄 Build Attempt $attempt of $MAX_ATTEMPTS${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    # 触发构建
    trigger_build
    
    # 等待工作流开始
    echo -e "${YELLOW}⏳ Waiting for workflow to start...${NC}"
    sleep 10
    
    # 监控构建状态
    echo -e "${YELLOW}👀 Monitoring build progress...${NC}"
    
    monitoring_time=0
    last_status=""
    
    while true; do
        workflow_info=$(get_latest_workflow_status)
        status=$(echo $workflow_info | jq -r '.[0].status // "unknown"')
        conclusion=$(echo $workflow_info | jq -r '.[0].conclusion // "unknown"')
        url=$(echo $workflow_info | jq -r '.[0].url // ""')
        created=$(echo $workflow_info | jq -r '.[0].createdAt // ""')
        
        # 如果状态发生变化，显示更新
        if [ "$status" != "$last_status" ]; then
            show_workflow_status "$status" "$conclusion" "$url"
            last_status="$status"
        fi
        
        # 检查构建是否完成
        if [ "$status" = "completed" ]; then
            if [ "$conclusion" = "success" ]; then
                echo -e "${GREEN}🎉 BUILD SUCCESSFUL!${NC}"
                echo -e "${GREEN}==========================================${NC}"
                echo -e "${GREEN}✅ All checks passed${NC}"
                echo -e "${GREEN}✅ Deployment completed${NC}"
                echo -e "${GREEN}✅ Application is live${NC}"
                echo -e "${GREEN}==========================================${NC}"
                
                if [ -n "$url" ]; then
                    echo -e "${BLUE}📋 Build Details: $url${NC}"
                fi
                
                build_success=true
            else
                echo -e "${RED}❌ BUILD FAILED${NC}"
                echo -e "${RED}==========================================${NC}"
                echo -e "${RED}Conclusion: $conclusion${NC}"
                
                if [ -n "$url" ]; then
                    echo -e "${YELLOW}📋 View logs: $url${NC}"
                fi
                
                # 准备重试
                if [ $attempt -lt $MAX_ATTEMPTS ]; then
                    echo -e "${YELLOW}🔄 Preparing for retry in $WAIT_BETWEEN_ATTEMPTS seconds...${NC}"
                    echo ""
                fi
            fi
            break
        fi
        
        # 显示进度
        echo -ne "⏱️  Monitoring: ${monitoring_time}s elapsed... "
        
        if [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; then
            echo -e "${YELLOW}$status${NC}"
        else
            echo -e "${BLUE}$status${NC}"
        fi
        
        # 等待下一次检查
        sleep $MONITOR_INTERVAL
        monitoring_time=$((monitoring_time + MONITOR_INTERVAL))
        
        # 如果监控时间过长（30分钟），中断
        if [ $monitoring_time -ge 1800 ]; then
            echo -e "${YELLOW}⚠️  Monitoring timeout (30 minutes)${NC}"
            echo -e "${YELLOW}Workflow may be stuck. Check manually.${NC}"
            break
        fi
    done
    
    # 如果构建成功，退出循环
    if [ "$build_success" = true ]; then
        break
    fi
    
    # 如果还有重试次数，等待后继续
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        attempt=$((attempt + 1))
        echo -e "${YELLOW}⏳ Waiting $WAIT_BETWEEN_ATTEMPTS seconds before next attempt...${NC}"
        sleep $WAIT_BETWEEN_ATTEMPTS
    else
        attempt=$((attempt + 1))
    fi
done

# 最终结果
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}🏁 Build Process Complete${NC}"
echo -e "${BLUE}==========================================${NC}"

if [ "$build_success" = true ]; then
    echo -e "${GREEN}✅ SUCCESS: Build completed after $((attempt-1)) attempt(s)${NC}"
    
    # 尝试获取部署URL
    echo -e "${YELLOW}🔍 Checking deployment status...${NC}"
    
    # 如果有cloudbaserc.json，提取环境ID
    if [ -f "cloudbaserc.json" ]; then
        ENV_ID=$(grep -o '"envId": *"[^"]*"' cloudbaserc.json | cut -d'"' -f4)
        if [ -n "$ENV_ID" ]; then
            DEPLOY_URL="https://${ENV_ID}-1256169472.tcloudbaseapp.com"
            echo -e "${GREEN}🌐 Your application is live at:${NC}"
            echo -e "${BLUE}   $DEPLOY_URL${NC}"
            echo -e "${BLUE}   $DEPLOY_URL/anki学习系统.html${NC}"
        fi
    fi
    
    # 发送完成通知（如果需要）
    echo -e "${GREEN}📨 Build successful! You can now access your deployed application.${NC}"
    exit 0
else
    echo -e "${RED}❌ FAILURE: Build failed after $MAX_ATTEMPTS attempts${NC}"
    echo -e "${YELLOW}⚠️  Please check the workflow logs for details.${NC}"
    echo -e "${YELLOW}⚠️  You may need to:${NC}"
    echo -e "${YELLOW}   1. Check GitHub Secrets configuration${NC}"
    echo -e "${YELLOW}   2. Verify CloudBase environment access${NC}"
    echo -e "${YELLOW}   3. Check network connectivity${NC}"
    exit 1
fi