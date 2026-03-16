#!/bin/bash

# 验证 CloudBase 部署脚本
# 在完成 GitHub Actions 配置后运行此脚本进行验证

set -e

echo "🔍 开始验证 CloudBase 部署配置"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必要的文件
echo "📁 检查必要文件..."
required_files=(
  "anki学习系统.html"
  "cards_data.json"
  "cloudbaserc.json"
  ".github/workflows/deploy-to-cloudbase.yml"
)

missing_files=0
for file in "${required_files[@]}"; do
  if [ -f "$file" ] || [ -d "$(dirname "$file")" ]; then
    echo -e "${GREEN}✅${NC} 找到: $file"
  else
    echo -e "${RED}❌${NC} 缺少: $file"
    missing_files=$((missing_files + 1))
  fi
done

if [ $missing_files -gt 0 ]; then
  echo -e "${RED}错误: 缺少 $missing_files 个必要文件${NC}"
  exit 1
fi

# 检查 cloudbaserc.json 配置
echo "⚙️  检查 CloudBase 配置..."
ENV_ID=$(grep -o '"envId": *"[^"]*"' cloudbaserc.json | cut -d'"' -f4)
if [ -z "$ENV_ID" ]; then
  echo -e "${RED}❌ 在 cloudbaserc.json 中未找到 envId${NC}"
  exit 1
else
  echo -e "${GREEN}✅${NC} 环境ID: $ENV_ID"
fi

# 检查 .gitignore 配置
echo "📋 检查 .gitignore 配置..."
if [ -f ".gitignore" ]; then
  echo -e "${GREEN}✅${NC} .gitignore 文件存在"
  # 检查是否排除了不必要的文件
  if grep -q "deploy/" .gitignore; then
    echo -e "${GREEN}✅${NC} deploy/ 目录已被忽略"
  else
    echo -e "${YELLOW}⚠️  deploy/ 目录未被忽略${NC}"
  fi
else
  echo -e "${RED}❌ 缺少 .gitignore 文件${NC}"
fi

# 检查 GitHub Actions 工作流
echo "🔄 检查 GitHub Actions 工作流..."
WORKFLOW_FILE=".github/workflows/deploy-to-cloudbase.yml"
if [ -f "$WORKFLOW_FILE" ]; then
  echo -e "${GREEN}✅${NC} GitHub Actions 工作流文件存在"
  
  # 检查工作流基本结构
  if grep -q "name: Deploy to CloudBase" "$WORKFLOW_FILE"; then
    echo -e "${GREEN}✅${NC} 工作流名称正确"
  fi
  
  if grep -q "on:" "$WORKFLOW_FILE"; then
    echo -e "${GREEN}✅${NC} 触发器配置存在"
  fi
  
  if grep -q "CLOUDBASE_ENVID" "$WORKFLOW_FILE"; then
    echo -e "${GREEN}✅${NC} CloudBase 环境变量引用正确"
  fi
else
  echo -e "${RED}❌ 缺少 GitHub Actions 工作流文件${NC}"
fi

# 生成部署URL
DEPLOY_URL="https://${ENV_ID}-1256169472.tcloudbaseapp.com"
echo ""
echo "🌐 部署信息:"
echo "   环境ID: $ENV_ID"
echo "   部署URL: $DEPLOY_URL"
echo "   GitHub仓库: https://github.com/JanusChoi/quant-lesson-101"
echo "   GitHub Actions: https://github.com/JanusChoi/quant-lesson-101/actions"

# 测试当前网站可访问性
echo ""
echo "📡 测试当前网站可访问性..."
if command -v curl &> /dev/null; then
  echo "测试 $DEPLOY_URL ..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOY_URL" || echo "ERROR")
  
  case $HTTP_STATUS in
    200|301|302)
      echo -e "${GREEN}✅ 网站可访问 (HTTP $HTTP_STATUS)${NC}"
      echo -e "${GREEN}   请访问: $DEPLOY_URL${NC}"
      ;;
    404)
      echo -e "${YELLOW}⚠️  网站返回 404 (未找到)${NC}"
      echo "   这可能是因为:"
      echo "   1. 尚未部署"
      echo "   2. 部署失败"
      echo "   3. 根路径重定向配置问题"
      ;;
    ERROR)
      echo -e "${RED}❌ 无法连接到网站${NC}"
      ;;
    *)
      echo -e "${YELLOW}⚠️  网站返回 HTTP $HTTP_STATUS${NC}"
      ;;
  esac
  
  # 测试应用页面
  APP_URL="${DEPLOY_URL}/anki学习系统.html"
  echo "测试 $APP_URL ..."
  APP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || echo "ERROR")
  
  if [ "$APP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ 应用页面可访问${NC}"
  else
    echo -e "${YELLOW}⚠️  应用页面返回 HTTP $APP_STATUS${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  未找到 curl 命令，跳过网站测试${NC}"
fi

# 最终建议
echo ""
echo "📋 下一步操作建议:"
echo "1. 确保以下 GitHub Secrets 已配置:"
echo "   - CLOUDBASE_ENVID = $ENV_ID"
echo "   - CLOUDBASE_SECRETID (你的腾讯云SecretId)"
echo "   - CLOUDBASE_SECRETKEY (你的腾讯云SecretKey)"
echo ""
echo "2. 推送代码到 GitHub:"
echo "   git add ."
echo "   git commit -m 'Add deployment configuration'"
echo "   git push origin main"
echo ""
echo "3. 或者在 GitHub 网页界面上传文件:"
echo "   https://github.com/JanusChoi/quant-lesson-101"
echo ""
echo "4. 监控部署状态:"
echo "   https://github.com/JanusChoi/quant-lesson-101/actions"
echo ""
echo "5. 验证部署结果:"
echo "   访问: $DEPLOY_URL"
echo ""
echo -e "${GREEN}✅ 验证完成！${NC}"