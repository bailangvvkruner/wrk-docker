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
    # 创建必要的目录和符号链接，确保能找到LuaJIT头文件
    && mkdir -p /usr/local/include /usr/local/lib \
    && echo "准备LuaJIT头文件环境..." \
    # 先正常编译一次，让LuaJIT被构建和安装
    && make -j$(nproc) WITH_OPENSSL=1 \
    # 创建符号链接，确保后续静态编译能找到LuaJIT
    && if [ -d /wrk/obj/include/luajit-2.1 ]; then \
         ln -sf /wrk/obj/include/luajit-2.1/* /usr/local/include/ 2>/dev/null || true; \
         ln -sf /wrk/obj/lib/* /usr/local/lib/ 2>/dev/null || true; \
       fi \
    # 清理并重新静态编译
    && make clean \
    && make -j$(nproc) WITH_OPENSSL=1 \
    CC="gcc" \
    CFLAGS="-static -O3" \
    LDFLAGS="-static -Wl,--strip-all" \
    && echo "编译成功，测试wrk基本功能:" \
    && ./wrk --version \
    && echo "优化和压缩..." \
    && strip -v --strip-all ./wrk \
    && upx --best --lzma ./wrk \
    && echo "最终文件信息:" \
    && ls -lh ./wrk \
    && echo "验证最终文件可执行性:" \
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
