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
    # 克隆wrk源码
    && git clone https://github.com/wg/wrk.git --depth 1 \
    && cd wrk \
    # 编译wrk（添加静态链接标志以确保在scratch中运行）
    && make -j$(nproc) WITH_OPENSSL=1 \
    CC="gcc" \
    CFLAGS="-static -O3" \
    LDFLAGS="-static -Wl,--strip-all" \
    && echo "编译成功，测试wrk基本功能:" \
    && ./wrk --version \
    && echo "二进制文件信息:" \
    && file ./wrk \
    && ls -lh ./wrk \
    # 优化和压缩
    && strip -v --strip-all ./wrk \
    && echo "剥离调试信息后:" \
    && ls -lh ./wrk \
    && upx --best --lzma ./wrk \
    && echo "UPX压缩后最终大小:" \
    && ls -lh ./wrk \
    && echo "验证压缩后文件仍可执行:" \
    && ./wrk --version


# 阶段2: 运行层
# FROM alpine:3.19
FROM scratch

# # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]

# 只复制编译好的二进制文件（二进制位于/wrk/wrk目录内）
COPY --from=builder /wrk/wrk /wrk
# 设置容器启动命令
ENTRYPOINT ["/wrk"]

# # 阶段2: 运行层
# FROM alpine:3.19

# # 安装运行时最小依赖
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]
