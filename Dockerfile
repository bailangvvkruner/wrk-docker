# 最小化wrk Docker镜像构建
# 基于多阶段构建和Alpine Linux，最终镜像约8MB

# 阶段1: 编译层
FROM alpine:3.19 AS builder

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
    && make -j$(nproc) WITH_OPENSSL=1 \
    && echo "编译成功，二进制文件位置和大小:" \
    && ls -lh ./wrk \
    && strip -v --strip-all ./wrk \
    && echo "剥离调试信息后:" \
    && ls -lh ./wrk \
    && upx --best --lzma ./wrk \
    && echo "UPX压缩后最终大小:" \
    && du -b ./wrk \
    && echo "查找所有wrk相关文件:" \
    && find / -name "*wrk*" -type f \
    && echo "当前目录内容:" \
    && pwd && ls -la


# # 阶段2: 运行层
# FROM alpine:3.19

# # # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # # 从编译层复制wrk二进制文件
# # COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # # 设置入口点
# # ENTRYPOINT ["/usr/local/bin/wrk"]

# # 只复制编译好的二进制文件（二进制位于/wrk/wrk目录内）
# COPY --from=builder /wrk/wrk /wrk
# # 设置容器启动命令
# ENTRYPOINT ["/wrk"]

# 阶段2: 运行层
# 使用 bitnami/libgcc 提供 libgcc 运行时支持
# FROM bitnami/libgcc:latest
FROM scratch

# 从Alpine容器中复制libgcc库
COPY --from=builder /lib/libgcc_s.so.1 /lib/
# 从编译层复制wrk二进制文件（二进制文件是 /wrk/wrk）
COPY --from=builder /wrk/wrk /wrk
ENTRYPOINT ["/wrk"]
