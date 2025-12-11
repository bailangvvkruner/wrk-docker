# 最小化wrk Docker镜像构建
# 基于多阶段构建和Alpine Linux，最终镜像约8MB

# 阶段1: 编译层
FROM alpine:3.19 AS builder

# 安装构建依赖（包含OpenSSL静态库）
RUN set -eux \
    && FILENAME=wrk \
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
    && git clone https://github.com/wg/wrk.git --depth 1 && \
    cd wrk && \
    # 清理并一次性进行静态编译
    && make clean \
    && make -j$(nproc) WITH_OPENSSL=1 \
    CC="gcc" \
    CFLAGS="-static -O3 -static-libgcc" \
    LDFLAGS="-static -static-libgcc -Wl,--strip-all" \
    && echo "Binary size after build:" \
    && du -b ./wrk \
    && strip -v --strip-all ./wrk \
    && echo "Binary size after stripping:" \
    && du -b ./wrk \
    && upx --best --lzma ./wrk \
    && echo "Binary size after upx:" \
    && du -b ./wrk

# 阶段2: 运行层
# FROM alpine:3.19
FROM scratch

# # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]

# 只复制静态编译的二进制文件
COPY --from=builder /wrk/wrk /wrk
# 设置容器启动命令
ENTRYPOINT ["/wrk"]
