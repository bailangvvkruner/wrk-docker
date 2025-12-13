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
    && echo "=== 开始动态编译 wrk ===" \
    # && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    # && echo "=== 静态编译成功，生成二进制文件 ===" \
    # 使用系统OpenSSL库进行动态编译
    && make -j$(nproc) STATIC=0 WITH_OPENSSL=/usr \
    && echo "=== 动态编译成功，生成二进制文件 ===" \
    && ls -lh ./wrk \
    && echo "=== 剥离调试信息 ===" \
    && strip -v --strip-all ./wrk \
    && echo "=== 剥离后文件信息 ===" \
    # && ls -lh ./wrk \
    # && echo "=== UPX压缩 ===" \
    # && upx --best --lzma ./wrk \
    # && echo "=== 压缩后文件信息 ===" \
    && ls -lh ./wrk


# 阶段2: 运行层

# FROM alpine:3.19
# # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]    # 阶段2: 运行层 - 使用scratch镜像（最小化）
FROM scratch

# 复制动态链接所需的库文件
# musl libc 加载器
COPY --from=builder /lib/ld-musl-x86_64.so.1 /lib/
# GCC 运行时库
COPY --from=builder /usr/lib/libgcc_s.so.1 /usr/lib/
# OpenSSL 库（Alpine 使用 OpenSSL 3.x）
COPY --from=builder /usr/lib/libssl.so.3 /usr/lib/
COPY --from=builder /usr/lib/libcrypto.so.3 /usr/lib/

# 复制/etc/services文件用于服务名解析
COPY --from=builder /etc/services /etc/services

# 复制wrk二进制文件
COPY --from=builder /wrk/wrk /wrk

# 设置入口点
ENTRYPOINT ["/wrk"]
