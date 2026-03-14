# FROM ubuntu:22.04
FROM nvidia/cuda:12.4.0-devel-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive
# 使用阿里云源（替换原有sources.list，避免手动拷贝出错）
RUN echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list

# Install packages（移除ARM交叉编译相关依赖）
RUN set -eux \
    && apt-get update \
    && apt-get -yq upgrade \
    && apt-get -yq install \
        aptitude apt-rdepends bash build-essential ccache clang clang-tidy cppcheck curl doxygen diffstat gawk gdb git gnupg gperf iputils-ping \
        linux-tools-generic nano nasm ninja-build openssh-server openssl pkg-config python3 python-is-python3 spawn-fcgi net-tools iproute2 \
        sudo tini unzip valgrind wget zip texinfo chrpath socat cpio xz-utils debianutils \
        patch perl tar rsync bc xterm whois software-properties-common apt-transport-https ca-certificates\
        dh-autoreconf apt-transport-https g++ graphviz xdot mesa-utils \
        mysql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && exit 0

# Install cmake (修复Kitware源公钥问题)
RUN set -eux \
    && apt-get update \
    # 安装必要依赖并添加Kitware官方源 + 保留公钥
    && apt-get install -yq apt-transport-https ca-certificates gnupg \
    && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - > /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main" | tee /etc/apt/sources.list.d/kitware.list > /dev/null \
    # 更新源并安装cmake（指定3.28版本）
    && apt-get update \
    && apt-get install -yq cmake=3.28.5-0kitware1ubuntu22.04.1 cmake-data=3.28.5-0kitware1ubuntu22.04.1 \
    # 保留公钥（关键：避免后续update验证失败）
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # 验证安装
    && cmake --version \
    && exit 0

# Install python pip
RUN set -eux \
    && python3 --version \
    && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    && python3 get-pip.py \
    && rm get-pip.py \
    && python3 -m pip install -U pip \
    && pip3 --version \
    && pip3 install --upgrade pip setuptools wheel \
    && pip3 --version \
    && exit 0

# ========== 核心修改：指定安装PyTorch 2.5.1（适配CUDA 12.7） ==========
RUN set -eux \
    && pip3 install --upgrade pip \
    # 强制指定PyTorch 2.5.1版本，使用阿里云镜像加速
    && pip3 install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://mirrors.aliyun.com/pypi/simple/ \
    # 验证安装结果（确保版本和CUDA可用性）
    && python3 -c "import torch; print(f'PyTorch版本: {torch.__version__}'); print(f'CUDA是否可用: {torch.cuda.is_available()}'); print(f'CUDA版本: {torch.version.cuda}')" \
    && exit 0

# Install python packages
RUN set -eux \
    && pip3 --version \
    && pip3 install --upgrade pip setuptools wheel \
    && pip3 --version \
    && pip3 install --upgrade autoenv autopep8 cmake-format clang-format conan meson \
    && pip3 install --upgrade cppclean flawfinder lizard pygments pybind11 GitPython pexpect subunit Jinja2 pylint CLinters \
    && exit 0

# Install libraries (手动编译mlpack，解决包找不到问题)
RUN set -eux \
    # 1. 更新源并安装基础依赖（不含mlpack）
    && apt-get update \
    && apt-get install -yq \
        # 图形/系统库依赖
        libgl-dev libgl1-mesa-dev \
        libx11-xcb-dev libfontenc-dev libice-dev libsm-dev libxaw7-dev libxcomposite-dev libxcursor-dev libxdamage-dev libxext-dev \
        libxfixes-dev libxi-dev libxinerama-dev libxkbfile-dev libxmu-dev libxmuu-dev libxpm-dev libxrandr-dev libxrender-dev libxres-dev \
        libxss-dev libxt-dev libxtst-dev libxv-dev libxxf86vm-dev libxcb-glx0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-xkb-dev \
        libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-sync-dev libxcb-xfixes0-dev \
        libxcb-xinerama0-dev libxcb-dri3-dev uuid-dev libxcb-cursor-dev libxcb-dri2-0-dev libxcb-present-dev \
        libxcb-composite0-dev libxcb-ewmh-dev libxcb-res0-dev libxcb-util-dev libxcb-util0-dev \
        # InfluxDB C++ 客户端依赖
        libcurl4-openssl-dev libssl-dev libjsoncpp-dev libfmt-dev \
        # mlpack编译依赖
        libboost-all-dev libcereal-dev libopenblas-dev liblapack-dev \
        # Armadillo
        libarmadillo-dev \
        # 安装Boost库
        libboost-math-dev libboost-program-options-dev libboost-random-dev libboost-test-dev libxml2-dev \
        # 安装mlpack
        libmlpack-dev \
        # 安装jsoncpp
        libjsoncpp-dev \
    # # 2. 手动编译安装armadillo（mlpack核心依赖）
    # && wget -q https://sourceforge.net/projects/arma/files/armadillo-12.8.2.tar.xz -O /tmp/armadillo.tar.xz \
    # && mkdir -p /tmp/armadillo && tar -xf /tmp/armadillo.tar.xz -C /tmp/armadillo --strip-components=1 \
    # && cd /tmp/armadillo && mkdir build && cd build \
    # && cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_OPENBLAS=ON .. \
    # && make -j$(nproc) && make install \
    # # 3. 手动编译安装ensmallen（mlpack优化库）
    # && wget -q https://github.com/mlpack/ensmallen/archive/refs/tags/2.19.0.tar.gz -O /tmp/ensmallen.tar.gz \
    # && mkdir -p /tmp/ensmallen && tar -xf /tmp/ensmallen.tar.gz -C /tmp/ensmallen --strip-components=1 \
    # && cd /tmp/ensmallen && mkdir build && cd build \
    # && cmake -DCMAKE_BUILD_TYPE=Release .. \
    # && make -j$(nproc) && make install \
    # # 4. 手动编译安装mlpack
    # && wget -q https://github.com/mlpack/mlpack/archive/refs/tags/4.3.0.tar.gz -O /tmp/mlpack.tar.gz \
    # && mkdir -p /tmp/mlpack && tar -xf /tmp/mlpack.tar.gz -C /tmp/mlpack --strip-components=1 \
    # && cd /tmp/mlpack && mkdir build && cd build \
    # && cmake -DCMAKE_BUILD_TYPE=Release -DARMADILLO_INCLUDE_DIR=/usr/local/include -DENSMALLEN_INCLUDE_DIR=/usr/local/include .. \
    # && make -j$(nproc) && make install \
    # # 5. 清理编译文件，减小镜像体积
    # && ldconfig \
    # && rm -rf /tmp/* \
    && apt-get -yq autoremove \
    && apt-get -yq autoclean  \
    && apt-get -yq clean  \
    && rm -rf /var/lib/apt/lists/* \
    && exit 0
    
# Setup ssh
RUN set -eux \
    && mkdir -p /var/run/sshd \
    && mkdir -p /root/.ssh \
    && sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
    && echo 'root:root' | chpasswd \
    && exit 0

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/sbin/sshd","-D","-e"]
