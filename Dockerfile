# 最小化wrk Docker镜像构建
# 基于多阶段构建和Alpine Linux，最终镜像约8MB

# 阶段1: 编译层
FROM alpine:3.19 AS builder

# 安装构建依赖
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
    perl \
    # 包含strip命令
    binutils \
    upx \
    # 克隆并编译wrk
    && git clone https://github.com/wg/wrk.git --depth 1 && \
    cd wrk && \
    # 在编译前创建必要的目录和符号链接，确保能找到LuaJIT头文件
    mkdir -p /usr/local/include /usr/local/lib \
    # wrk的构建过程会将LuaJIT安装到/wrk/obj，我们需要让编译器能找到它
    && echo "Preparing build environment for LuaJIT headers..." \
    # 先正常编译，让LuaJIT被构建和安装
    && make clean \
    # 首次编译（这会构建LuaJIT）
    && make -j$(nproc) WITH_OPENSSL=1 \
    # 编译后创建符号链接，确保后续步骤能找到LuaJIT
    && if [ -d /wrk/obj/include/luajit-2.1 ]; then \
         ln -sf /wrk/obj/include/luajit-2.1/* /usr/local/include/ 2>/dev/null || true; \
         ln -sf /wrk/obj/lib/* /usr/local/lib/ 2>/dev/null || true; \
       fi \
    # 清理并重新编译，确保静态链接正确
    && make clean \
    # 重新编译，确保所有依赖都被正确静态链接
    && make -j$(nproc) WITH_OPENSSL=1 \
    CC="gcc" \
    # 关键修改：强制静态编译，确保libgcc被静态链接
    CFLAGS="-static -O3 -static-libgcc" \
    LDFLAGS="-static -static-libgcc -Wl,--strip-all" \
    # && ls -lh /wrk/wrk \
    && echo "Binary size after build:" \
    && du -b /wrk/$FILENAME \
    && strip -v --strip-all /wrk/wrk \
    # && ls -lh /wrk/wrk
    && echo "Binary size after stripping:" \
    && du -b /wrk/$FILENAME \
    && upx --best --lzma /wrk/$FILENAME \
    && echo "Binary size after upx:" \
    && du -b /wrk/$FILENAME

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
