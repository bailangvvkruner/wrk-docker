#!/bin/bash

# 简单的构建测试脚本
# 用于验证Dockerfile修复

echo "开始构建测试..."
echo "这将验证Dockerfile中的语法错误是否已修复"

# 构建镜像
docker build -t wrk:test .

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！Dockerfile语法错误已修复"
    echo "镜像大小:"
    docker images wrk:test --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    echo ""
    echo "运行测试:"
    echo "docker run --rm wrk:test --help"
else
    echo "❌ 构建失败，仍有语法错误"
    exit 1
fi