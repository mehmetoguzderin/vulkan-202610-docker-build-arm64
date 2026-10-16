# nvpro-build: arm64 build image for nvpro-samples

Ubuntu 26.04 image that rebuilds the Vulkan SDK 1.4.363.0 components (loader, glslang, SPIRV-Tools, shaderc, Vulkan-Utility-Libraries) natively for aarch64, then builds samples such as `vk_mini_samples` / `ray_query`.

Verified: `ray_query` built for linux/arm64 (132 of 132 steps), and the output is an aarch64 ELF executable.

## Prerequisites
- Docker with buildx.
- On an x86-64 host, register arm64 emulation first:
  ```
  docker run --privileged --rm tonistiigi/binfmt --install arm64
  ```
  The image build fails on purpose if it isn't running as aarch64.

## Build the image
```
docker buildx build \
  --platform linux/arm64 \
  --load \
  --build-arg JOBS=4 \
  -t nvpro-build:26.04-arm64 .
```
Optional build args:
- `JOBS`: parallel jobs for the SDK build (default 4).
- `SDK_VERSION`: LunarG SDK version (default 1.4.363.0).
- `APT_HTTPS=1`: switch apt to HTTPS mirrors, for networks that block plain HTTP to ports.ubuntu.com. apt GPG signature checks stay on.

## Build ray_query
```
mkdir -p nvpro && cd nvpro
git clone https://github.com/nvpro-samples/nvpro_core2.git
git clone https://github.com/nvpro-samples/vk_mini_samples.git

docker run --rm \
  --platform linux/arm64 \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$PWD:/work" \
  -w /work/vk_mini_samples \
  nvpro-build:26.04-arm64 \
  bash -c '
    set -eu
    cmake -S . -B build-arm64 -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DGLFW_BUILD_WAYLAND=OFF
    cmake --build build-arm64 --target ray_query --parallel 4
  '
```
The output goes to `vk_mini_samples/_bin/Release/ray_query`.

## Timing (x86-64 host, qemu emulation, 4 jobs)
- Image build: about 2h45m (mostly the SDK compile).
- ray_query configure and build: about 28 min.
Running on a native arm64 host is much faster.
