# 分布式WRK Docker镜像构建
# 包含：wrk (原版), wrk-master (命令端), wrk-worker (任务机)

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
    # 克隆包含分布式功能的wrk源码
    && git clone -b both https://github.com/bailangvvkruner/wrk.git --depth 1 \
    && cd wrk \
    # 编译所有二进制文件（原版wrk + 分布式组件）
    && make -j$(nproc) WITH_OPENSSL=0 \
    && echo "编译成功，二进制文件列表:" \
    && ls -lh ./wrk ./wrk-master ./wrk-worker 2>/dev/null || true \
    # 剥离调试信息
    && strip -v --strip-all ./wrk \
    && strip -v --strip-all ./wrk-master 2>/dev/null || true \
    && strip -v --strip-all ./wrk-worker 2>/dev/null || true \
    && echo "剥离调试信息后:" \
    && ls -lh ./wrk ./wrk-master ./wrk-worker 2>/dev/null || true \
    # UPX压缩
    && upx --best --lzma ./wrk \
    && upx --best --lzma ./wrk-master 2>/dev/null || true \
    && upx --best --lzma ./wrk-worker 2>/dev/null || true \
    && echo "UPX压缩后最终大小:" \
    && du -b ./wrk ./wrk-master ./wrk-worker 2>/dev/null || true


# 阶段2: 运行层
FROM alpine:3.19

# 安装运行时依赖
RUN apk add --no-cache libgcc

# 从编译层复制所有二进制文件
COPY --from=builder /wrk/wrk /usr/local/bin/wrk
COPY --from=builder /wrk/wrk-master /usr/local/bin/wrk-master
COPY --from=builder /wrk/wrk-worker /usr/local/bin/wrk-worker

# 创建智能启动脚本
RUN cat > /usr/local/bin/entrypoint.sh << 'EOF'
#!/bin/sh
# 智能入口点脚本
# 根据第一个参数决定启动哪个组件

if [ "$1" = "master" ]; then
    shift
    exec wrk-master "$@"
elif [ "$1" = "worker" ]; then
    shift
    exec wrk-worker "$@"
else
    # 默认运行原版wrk
    exec wrk "$@"
fi
EOF
&& chmod +x /usr/local/bin/entrypoint.sh

# 设置入口点
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 默认命令（显示帮助）
CMD ["--help"]
