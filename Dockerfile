# 极限优化wrk Docker镜像构建
# 基于多阶段构建，最终使用scratch镜像
# 
# 架构特定优化:
# - x86_64: 启用AVX2、BMI2、FMA等现代指令集 (march=x86-64-v3)
# - ARM64: 启用NEON、FP16、DOTPROD、CRYPTO等高级指令集 (march=armv8.2-a+crypto+fp16+dotprod)
# - ARMv7: 启用NEON和VFPv4优化 (march=armv7-a+fp)
# - ARMv6: 启用基础NEON优化 (march=armv6)
# - x86_32: 启用SSE和MMX优化 (march=i686)
#
# 通用优化技术:
# - Ofast优化级别 + LTO链接时优化
# - 快速数学运算 + 循环展开 + 向量化
# - 图优化 + 嵌套循环优化 + 过程间分析
# - 静态链接 + 死代码消除 + 符号剥离
# - UPX极致压缩
#
# Ofast优化说明:
# - Ofast是比O3更激进的优化级别，专注于最大性能
# - 允许编译器进行激进优化，可能违反严格的IEEE/ISO标准
# - 适用于性能关键型应用，如wrk压力测试工具
# - 可能会增加编译时间和二进制大小，但提供最佳运行时性能

# 阶段1: 编译层
FROM alpine:latest AS builder

# 安装构建依赖（包括OpenSSL静态库和命令行工具）
# 极限优化：添加更多构建工具和依赖
RUN set -eux \
    && FILENAME=wrk \
    && apk add --no-cache --no-scripts --virtual .build-deps \
    git \
    # make \
    # gcc \
    # musl-dev \
    build-base \
    libbsd-dev \
    zlib-dev \
    perl \
    binutils \
    # upx \
    openssl \
    openssl-dev \
    openssl-libs-static \
    # 极限优化：添加额外依赖
    linux-headers \
    pkgconfig \
    # 尝试安装 upx，如果不可用则继续（某些架构可能不支持）
    \
    && apk add --no-cache --no-scripts --virtual .upx-deps \
        upx 2>/dev/null || echo "upx not available, skipping compression" \
    \
    # && \
    # 克隆wrk源码（使用static分支）并编译
    # set -eux \
    && git clone -b static https://github.com/bailangvvkruner/wrk --depth 1 \
    && cd wrk \
    # 显示环境信息用于调试
    && echo "=== 构建环境信息 ===" \
    && pwd \
    && ls -la \
    && echo "=== OpenSSL 版本信息 ===" \
    && openssl version \
    # 极限优化：显示更多环境信息
    && echo "=== 编译器信息 ===" \
    && gcc --version \
    && echo "=== CPU信息 ===" \
    && cat /proc/cpuinfo | grep -E "(model name|flags)" | head -5 \
    && echo "=== 架构信息 ===" \
    && uname -m \
    # 极限优化：设置编译环境变量
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then \
        echo "=== x86_64架构，启用AVX2和高级指令集优化 ===" \
        && export CFLAGS="-std=c99 -Wall -Ofast -march=x86-64-v3 -mtune=generic -flto=auto -ffast-math -funroll-loops -fprefetch-loop-arrays -fgraphite-identity -floop-nest-optimize -fipa-pta -ftree-vectorize -frename-registers -freorder-blocks -fsched2-use-superblocks -D_REENTRANT -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE -D_DEFAULT_SOURCE" \
        && export LDFLAGS="-static -Wl,-O3 -Wl,--gc-sections -Wl,--strip-all -Wl,-E -flto=auto -Wl,--sort-common -Wl,--as-needed" \
        && export OPENSSL_OPTS="no-shared no-psk no-srp no-dtls no-idea no-ssl3 no-weak-ssl-ciphers no-comp no-zlib no-zlib-dynamic no-dynamic-engine --prefix=/usr --libdir=lib -Ofast -march=x86-64-v3 -mtune=generic" \
    ; elif [ "$ARCH" = "aarch64" ]; then \
        echo "=== ARM64架构，启用ARM NEON和高级指令集优化 ===" \
        && export CFLAGS="-std=c99 -Wall -Ofast -march=armv8.2-a+crypto+fp16+dotprod -mtune=generic -flto=auto -ffast-math -funroll-loops -fprefetch-loop-arrays -fgraphite-identity -floop-nest-optimize -fipa-pta -ftree-vectorize -frename-registers -freorder-blocks -fsched2-use-superblocks -D_REENTRANT -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE -D_DEFAULT_SOURCE" \
        && export LDFLAGS="-static -Wl,-O3 -Wl,--gc-sections -Wl,--strip-all -Wl,-E -flto=auto -Wl,--sort-common -Wl,--as-needed" \
        && export OPENSSL_OPTS="no-shared no-psk no-srp no-dtls no-idea no-ssl3 no-weak-ssl-ciphers no-comp no-zlib no-zlib-dynamic no-dynamic-engine --prefix=/usr --libdir=lib -Ofast -march=armv8.2-a+crypto+fp16+dotprod -mtune=generic" \
    ; elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv6l" ]; then \
        echo "=== ARM32架构，启用ARM NEON优化 ===" \
        && export CFLAGS="-std=c99 -Wall -Ofast -march=armv7-a+fp -mtune=generic-armv7-a -flto=auto -ffast-math -funroll-loops -fprefetch-loop-arrays -fgraphite-identity -floop-nest-optimize -fipa-pta -ftree-vectorize -frename-registers -freorder-blocks -fsched2-use-superblocks -D_REENTRANT -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE -D_DEFAULT_SOURCE" \
        && export LDFLAGS="-static -Wl,-O3 -Wl,--gc-sections -Wl,--strip-all -Wl,-E -flto=auto -Wl,--sort-common -Wl,--as-needed" \
        && export OPENSSL_OPTS="no-shared no-psk no-srp no-dtls no-idea no-ssl3 no-weak-ssl-ciphers no-comp no-zlib no-zlib-dynamic no-dynamic-engine --prefix=/usr --libdir=lib -Ofast -march=armv7-a+fp -mtune=generic-armv7-a" \
    ; elif [ "$ARCH" = "i686" ] || [ "$ARCH" = "i386" ]; then \
        echo "=== x86_32架构，启用SSE和MMX优化 ===" \
        && export CFLAGS="-std=c99 -Wall -Ofast -march=i686 -mtune=generic -flto=auto -ffast-math -funroll-loops -fprefetch-loop-arrays -fgraphite-identity -floop-nest-optimize -fipa-pta -ftree-vectorize -frename-registers -freorder-blocks -fsched2-use-superblocks -D_REENTRANT -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE -D_DEFAULT_SOURCE" \
        && export LDFLAGS="-static -Wl,-O3 -Wl,--gc-sections -Wl,--strip-all -Wl,-E -flto=auto -Wl,--sort-common -Wl,--as-needed" \
        && export OPENSSL_OPTS="no-shared no-psk no-srp no-dtls no-idea no-ssl3 no-weak-ssl-ciphers no-comp no-zlib no-zlib-dynamic no-dynamic-engine --prefix=/usr --libdir=lib -Ofast -march=i686 -mtune=generic" \
    ; else \
        echo "=== 未知架构 $ARCH，使用通用优化 ===" \
        && export CFLAGS="-std=c99 -Wall -Ofast -march=native -mtune=native -flto=auto -ffast-math -funroll-loops -fprefetch-loop-arrays -fgraphite-identity -floop-nest-optimize -fipa-pta -ftree-vectorize -frename-registers -freorder-blocks -fsched2-use-superblocks -D_REENTRANT -D_POSIX_C_SOURCE=200112L -D_BSD_SOURCE -D_DEFAULT_SOURCE" \
        && export LDFLAGS="-static -Wl,-O3 -Wl,--gc-sections -Wl,--strip-all -Wl,-E -flto=auto -Wl,--sort-common -Wl,--as-needed" \
        && export OPENSSL_OPTS="no-shared no-psk no-srp no-dtls no-idea no-ssl3 no-weak-ssl-ciphers no-comp no-zlib no-zlib-dynamic no-dynamic-engine --prefix=/usr --libdir=lib -Ofast -march=native -mtune=native" \
    ; fi \
    && export MAKEFLAGS="-j$(nproc)" \
    && echo "=== 架构特定优化参数设置完成 ===" \
    && echo "CFLAGS: $CFLAGS" \
    && echo "LDFLAGS: $LDFLAGS" \
    && echo "OPENSSL_OPTS: $OPENSSL_OPTS" \
    # && echo "=== 开始动态编译 wrk ===" \
    # && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    # && echo "=== 静态编译成功，生成二进制文件 ===" \
    # # 使用系统OpenSSL库进行动态编译
    # # && make -j$(nproc) STATIC=0 WITH_OPENSSL=/usr \
    # # && echo "=== 动态编译成功，生成二进制文件 ===" \
    # 原始编译命令：make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    && echo "=== 极限优化编译成功，生成二进制文件 ===" \
    # 原始编译命令：make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    # && make -j$(nproc) STATIC=1 WITH_OPENSSL=/usr \
    && du -b ./wrk \
    && echo "=== 极限优化剥离调试信息 ===" \
    # 原始剥离命令：strip -v --strip-all ./$FILENAME \
    && strip -v --strip-all --remove-section=.comment --remove-section=.note --remove-section=.gnu.version ./$FILENAME \
    && du -b ./$FILENAME \
    && echo "极限优化剥离调试信息后:" \
    # 原始UPX命令：upx --best --lzma ./wrk \
    && (upx --best --lzma --brute ./$FILENAME 2>/dev/null || echo "upx compression skipped") \
    && du -b ./$FILENAME \
    && echo "=== 极限优化压缩后文件信息 ===" \
    && du -b ./$FILENAME \
    && echo "=== 剥离库文件调试信息 ===" \
    # && find /usr/lib -name "*.so*" -type f -exec strip -v --strip-all {} \; \
    # && find /lib -name "*.so*" -type f -exec strip -v --strip-all {} \;
    # && find / -name "*.*" -type f -exec strip -v --strip-all {} \;
    # && find / -name "*" -type f -exec strip -v --strip-all {} \; 2>/dev/null || true \
    && echo "====极限优化Done==="


# 阶段2: 运行层

# FROM alpine:3.19
# # 安装运行时依赖 - libgcc提供libgcc_s.so.1共享库
# RUN apk add --no-cache libgcc

# # 从编译层复制wrk二进制文件
# COPY --from=builder /wrk/wrk /usr/local/bin/wrk

# # 设置入口点
# ENTRYPOINT ["/usr/local/bin/wrk"]    # 阶段2: 运行层 - 使用scratch镜像（最小化）
FROM scratch AS final
# 还是要给开发者调试的
# FROM busybox:musl AS runpod

# # 复制动态链接所需的库文件
# # musl libc 加载器
# COPY --from=builder /lib/ld-musl-x86_64.so.1 /lib/
# # GCC 运行时库
# COPY --from=builder /usr/lib/libgcc_s.so.1 /usr/lib/
# # OpenSSL 库（Alpine 使用 OpenSSL 3.x）
# COPY --from=builder /usr/lib/libssl.so.3 /usr/lib/
# COPY --from=builder /usr/lib/libcrypto.so.3 /usr/lib/

# 复制/etc/services文件用于服务名解析 DNS解析要用
COPY --from=builder /etc/services /etc/services
# 复制/etc/nsswitch.conf文件用于DNS解析 host模式忽略
# COPY --from=builder /etc/nsswitch.conf /etc/nsswitch.conf

# 复制wrk二进制文件
COPY --from=builder /wrk/wrk /wrk

# 在Dockerfile的scratch阶段添加复制Lua脚本的指令
COPY --from=builder /wrk/scripts/ /scripts/
COPY --from=builder /wrk/src/wrk.lua /wrk.lua

# 设置入口点
ENTRYPOINT ["/wrk"]

# 极限优化：添加性能测试脚本示例
# 使用方法:
# docker run --rm wrk:ultra -t12 -c400 -d30s http://example.com
# 
# 性能测试示例:
# docker run --rm wrk:ultra -t12 -c400 -d30s --timeout 10s --latency http://example.com
#
# 多架构构建:
# docker buildx build --platform linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8 -t wrk:multi-arch --push .
