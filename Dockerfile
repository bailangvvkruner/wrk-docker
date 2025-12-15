# 分布式wrk Docker镜像构建
# 基于多阶段构建，最终使用scratch镜像

# 阶段1: 编译层
FROM alpine:latest AS builder

# 安装构建依赖
RUN apk add --no-cache --no-scripts --virtual .build-deps \
    git \
    make \
    gcc \
    musl-dev \
    libbsd-dev \
    zlib-dev \
    perl \
    binutils \
    upx \
    openssl \
    openssl-dev \
    openssl-libs-static

# 克隆wrk源码（使用包含分布式功能的分支）
RUN git clone -b both https://github.com/bailangvvkruner/wrk --depth 1

# 检查是否包含分布式功能文件
RUN cd wrk && \
    echo "=== 检查分布式功能文件 ===" && \
    ls -la src/distributed.* 2>/dev/null || echo "分布式文件不存在，需要添加" && \
    echo "=== 源代码文件列表 ===" && \
    find src -name "*.c" -o -name "*.h" | sort

# 编译wrk（静态编译）
RUN cd wrk && \
    echo "=== 开始编译分布式wrk ===" && \
    make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr && \
    echo "=== 编译成功 ===" && \
    ls -la wrk && \
    echo "=== 文件大小 ===" && \
    du -b ./wrk

# 优化二进制文件
RUN cd wrk && \
    echo "=== 优化二进制文件 ===" && \
    strip -v --strip-all ./wrk && \
    upx --best --lzma ./wrk && \
    echo "=== 优化后文件大小 ===" && \
    du -b ./wrk

# 阶段2: 运行层 - 使用scratch镜像（最小化）
FROM scratch AS final

# 复制wrk二进制文件
COPY --from=builder /wrk/wrk /wrk

# 复制必要的脚本文件
COPY --from=builder /wrk/scripts/ /scripts/
COPY --from=builder /wrk/src/wrk.lua /wrk.lua

# 设置入口点
ENTRYPOINT ["/wrk"]
