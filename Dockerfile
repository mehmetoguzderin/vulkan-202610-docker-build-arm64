FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SDK_VERSION=1.4.363.0
ARG JOBS=4

# Optional: switch apt to HTTPS (for networks that block plain HTTP to the
# Ubuntu mirrors). Package integrity is still enforced by apt's GPG signatures;
# peer verification is only relaxed until ca-certificates is installed.
ARG APT_HTTPS=0
RUN if [ "$APT_HTTPS" = 1 ]; then \
      sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources \
      && echo 'Acquire::https::Verify-Peer "false";' > /etc/apt/apt.conf.d/99bootstrap; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build git curl ca-certificates \
      pkg-config python3 python3-jsonschema xz-utils bison \
      libx11-dev libx11-xcb-dev libxcb1-dev libxcb-keysyms1-dev \
      libxcb-dri3-dev libxcb-randr0-dev libxcb-ewmh-dev \
      libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev \
      libxxf86vm-dev libtbb-dev libgl-dev \
      libwayland-dev libxkbcommon-dev wayland-protocols \
      libglm-dev libpng-dev liblz4-dev libzstd-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99bootstrap

# The official Linux tarball contains sources as well as x86-64 binaries.
# Rebuild the required components natively; do not use the x86-64 binaries.
RUN test "$(uname -m)" = aarch64 \
    && mkdir -p /opt/vulkan-sdk \
    && curl -fL --retry 3 \
      "https://sdk.lunarg.com/sdk/download/${SDK_VERSION}/linux/vulkansdk-linux-x86_64-${SDK_VERSION}.tar.xz" \
      -o /tmp/sdk.tar.xz \
    && tar -xJf /tmp/sdk.tar.xz -C /opt/vulkan-sdk \
    && cd "/opt/vulkan-sdk/${SDK_VERSION}" \
    && ./vulkansdk --skip-deps -j "${JOBS}" \
         vulkan-loader glslang spirv-tools shaderc vul \
    && test -d aarch64/include/vulkan \
    && rm -rf x86_64 source /tmp/sdk.tar.xz

ENV VULKAN_SDK=/opt/vulkan-sdk/${SDK_VERSION}/aarch64
ENV PATH=${VULKAN_SDK}/bin:${PATH}
ENV LD_LIBRARY_PATH=${VULKAN_SDK}/lib:${VULKAN_SDK}/lib/VulkanLoader/lib
ENV CMAKE_PREFIX_PATH=${VULKAN_SDK}:${VULKAN_SDK}/lib/VulkanLoader
ENV PKG_CONFIG_PATH=${VULKAN_SDK}/lib/pkgconfig:${VULKAN_SDK}/share/pkgconfig

WORKDIR /work
CMD ["/bin/bash"]
