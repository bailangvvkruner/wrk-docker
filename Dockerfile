# 最小化wrk Docker镜像构建
# 基于多阶段构建和Alpine Linux，最终镜像约8MB

# 阶段1: 编译层
FROM alpine:latest AS builder

# 安装构建依赖
RUN set -eux \
    && apk add --no-cache --no-scripts --virtual .build-deps \
    git \
    make \
    gcc \
    musl-dev \
    libbsd-dev \
    zlib-dev \
    openssl-dev \
    openssl-libs-static \
    perl \
    binutils \
    upx \
    libgcc \
    # 克隆wrk源码
    && git clone https://github.com/wg/wrk.git --depth 1 \
    && cd wrk \
    # 编译wrk（不使用UPX压缩，避免运行时问题）
    && make -j$(nproc) WITH_OPENSSL=0 \
    && echo "编译成功，二进制文件位置和大小:" \
    && ls -lh ./wrk \
    && strip -v --strip-all ./wrk \
    && echo "剥离调试信息后:" \
    && ls -lh ./wrk \
    openssl \
    openssl-dev \
    openssl-libs-static \
    ca-certificates \
    # && \
    # 克隆wrk源码（使用static分支）并编译
    # set -eux \
    && git clone -b static https://github.com/bailangvvkruner/wrk --depth 1 \
    && cd wrk \
    # 显示环境信息用于调试
    && echo "=== Build Environment Information ===" \
    && pwd \
    && ls -la \
    && echo "=== OpenSSL Version Information ===" \
    && openssl version \
    # && echo "=== Starting dynamic compilation of wrk ===" \
    && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    && echo "=== Static compilation successful, binary file generated ===" \
    # Use system OpenSSL library for dynamic compilation
    # && make -j$(nproc) STATIC=0 WITH_OPENSSL=/usr \
    # && echo "=== Dynamic compilation successful, binary file generated ===" \
    && du -b ./wrk \
    && echo "=== Stripping debug information ===" \
    && strip -v --strip-all ./wrk \
    && du -b ./wrk \
    && echo "After stripping debug information:" \
    && upx --best --lzma ./wrk \
    && echo "UPX压缩后最终大小:" \
    && du -b ./wrk \
    && echo "查找所有wrk相关文件:" \
    && find / -name "*wrk*" -type f \
    && echo "当前目录内容:" \
    && pwd && ls -la \
    && echo "=== File information after stripping ===" \
    && du -b ./wrk \
    && echo "=== Stripping library file debug information ===" \
    # && find /usr/lib -name "*.so*" -type f -exec strip -v --strip-all {} \; \
    # && find /lib -name "*.so*" -type f -exec strip -v --strip-all {} \;
    # && find / -name "*.*" -type f -exec strip -v --strip-all {} \;
    # && find / -name "*" -type f -exec strip -v --strip-all {} \; 2>/dev/null || true \
    && echo "=== Done ==="


# # 阶段2: 运行层
FROM alpine:3.19

# # # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
RUN apk add --no-cache libgcc

# # # 从编译层复制wrk二进制文件
COPY --from=builder /wrk/wrk /usr/local/bin/wrk
# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]    # 阶段2: 运行层 - 使用scratch镜像（最小化）
FROM scratch

# # 复制动态链接所需的库文件
# # musl libc 加载器
# COPY --from=builder /lib/ld-musl-x86_64.so.1 /lib/
# # GCC 运行时库
# COPY --from=builder /usr/lib/libgcc_s.so.1 /usr/lib/
# # OpenSSL 库（Alpine 使用 OpenSSL 3.x）
# COPY --from=builder /usr/lib/libssl.so.3 /usr/lib/
# COPY --from=builder /usr/lib/libcrypto.so.3 /usr/lib/

# # 复制/etc/services文件用于服务名解析
# COPY --from=builder /etc/services /etc/services

# 复制CA证书（SSL/TLS必需）
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制wrk二进制文件
COPY --from=builder /wrk/wrk /wrk
>>>>>>> Stashed changes

# 设置入口点
ENTRYPOINT ["/usr/local/bin/wrk"]

# # 只复制编译好的二进制文件（二进制位于/wrk/wrk目录内）
# COPY --from=builder /wrk/wrk /wrk
# # 设置容器启动命令
# ENTRYPOINT ["/wrk"]

# 阶段2: 运行层
# 使用 bitnami/libgcc 提供 libgcc 运行时支持
# FROM bitnami/libgcc:latest
# FROM scratch

# # 从Alpine容器中复制libgcc库
# COPY --from=builder /usr/lib/libgcc_s.so.1 /lib/
# # 从编译层复制wrk二进制文件（二进制文件是 /wrk/wrk）
# COPY --from=builder /wrk/wrk /wrk
# ENTRYPOINT ["/wrk"]
