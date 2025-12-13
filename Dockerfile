# 最小化wrk Docker镜像构建
# 基于多阶段构建，最终使用scratch镜像

# 阶段1: 编译层
FROM alpine:latest AS builder

# 安装构建依赖（包括OpenSSL静态库和命令行工具）
RUN set -eux \
    && apk add --no-cache --no-scripts --virtual .build-deps \
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

# 克隆wrk源码（使用static分支）并编译
RUN set -eux \
    && git clone -b static https://github.com/bailangvvkruner/wrk --depth 1 \
    && cd wrk \
    # 显示环境信息用于调试
    && echo "=== 构建环境信息 ===" \
    && pwd \
    && ls -la \
    && echo "=== OpenSSL 版本信息 ===" \
    && openssl version \
    && echo "=== 开始静态编译 wrk ===" \
    # 使用系统OpenSSL静态库进行编译
    && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    && echo "=== 静态编译成功，生成二进制文件 ===" \
    && ls -lh ./wrk \
    && echo "=== 剥离调试信息 ===" \
    && strip -v --strip-all ./wrk \
    && echo "=== 剥离后文件信息 ===" \
    && ls -lh ./wrk
    # && upx --best --lzma ./wrk \
    # && echo "UPX压缩后最终大小:" \
    # && du -b ./wrk \
    # && echo "查找所有wrk相关文件:" \
    # && find / -name "*wrk*" -type f \
    # && echo "当前目录内容:" \
    # && pwd && ls -la
    && ls -lh ./wrk

# # 阶段2: 运行层
# FROM alpine:3.19
# # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# 阶段2: 运行层 - 使用scratch镜像（最小化）

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]

FROM scratch

# 从编译层复制完全静态的wrk二进制文件
COPY --from=builder /wrk/wrk /wrk

# 设置入口点
ENTRYPOINT ["/wrk"]
