# Ubuntu 26.04.1 Desktop + KosmicKrisp Vulkan in UTM 5.0.8

IMPORTANT: With these versions, as of 2026 October 18, only MoltenVK backend enables vkcube GUI. You can swap KosmicKrisp and MoltenVK backend without recreating the VM.

The setup uses **QEMU with hardware CPU virtualization**, **VirGL/OpenGL for the desktop**, and **Venus → KosmicKrisp for Vulkan applications**. UTM 5.0.8 still documents a problem with Vulkan desktop rendering, so we’ll enable Vulkan after preparing the desktop. ([UTM Documentation][1])

## 1. Download UTM and Ubuntu

Download:

* **[UTM 5.0.8 — UTM.dmg](https://github.com/utmapp/UTM/releases/download/v5.0.8/UTM.dmg)**. Open it and drag **UTM.app** into **Applications**.
* **[Ubuntu 26.04.1 LTS Desktop ARM64 ISO](https://cdimage.ubuntu.com/ubuntu/releases/26.04/release/ubuntu-26.04.1-desktop-arm64.iso)**.

The Ubuntu filename should be **`ubuntu-26.04.1-desktop-arm64.iso`**. This is the generic ARM64 Desktop installer suitable for the VM. ([GitHub][2])

## 2. Configure UTM and create the VM

### Set the initial graphics preferences

Open **UTM → Settings → Display → QEMU Graphics Acceleration**:

| Setting              | Value during installation |
| -------------------- | ------------------------- |
| **Renderer Backend** | **ANGLE (Metal)**         |
| **Vulkan Driver**    | **Disabled**, temporarily |
| **FPS Limit**        | **60**                    |

These are global UTM preferences. ANGLE’s Metal backend supports the Vulkan integration we’ll enable later. ([UTM Documentation][3])

### Create the Ubuntu VM

Choose **Create New Virtual Machine → Virtualize → Linux**, then configure:

| Setting                                 | Value                           |
| --------------------------------------- | ------------------------------- |
| **Use Apple Virtualization**            | **Unchecked**                   |
| **Boot Image Type**                     | **Boot from ISO image**         |
| **Boot ISO Image**                      | The downloaded Ubuntu ARM64 ISO |
| **Memory**                              | **6144 MiB**                    |
| **CPU Cores**                           | **4**                           |
| **Enable display output**               | On                              |
| **Enable hardware OpenGL acceleration** | **On**                          |
| **Storage size**                        | **64 GiB**                      |

Skip shared folders for now, give the VM a name, and save it.

Before starting, open the VM’s **Edit → Display** settings:

* Confirm the display card is **`virtio-gpu-gl-pci (GPU Supported)`**.
* Set **Retina Mode** to **off**.

Keep the CPU model, firmware, networking and other advanced settings at their defaults. UTM requires an accelerated display card for Venus; disabling Retina reduces display processing and memory use. ([docs.getutm.app][4])

## 3. Install Ubuntu Desktop

Start the VM and follow the installer:

1. Choose your language, keyboard and network.
2. Select **Install Ubuntu → Interactive installation**.
3. Choose **Default selection** for the smaller desktop installation.
4. Choose **Erase disk and install Ubuntu**, targeting the VM’s **64 GiB virtual disk**.
5. Complete the account and timezone settings, review the summary, and install.

When prompted to restart, eject the ISO using UTM’s **CD/DVD → Clear** control, then continue booting into the installed system. ([Ubuntu Desktop documentation][5])

## 4. Update Ubuntu and prepare its desktop

**Run all commands below inside Ubuntu.**

Open Terminal and run:

```bash
sudo apt update
sudo apt upgrade
sudo apt install mesa-vulkan-drivers vulkan-tools mesa-utils \
  spice-vdagent qemu-guest-agent mpv
```

Ubuntu’s ARM64 Mesa package already supplies the **Venus Vulkan driver**. KosmicKrisp runs inside UTM on the Mac; Ubuntu uses Venus to communicate with it. The guest agents provide clipboard, display-resizing and VM-management integration. ([packages.ubuntu.com][6])

### Keep the desktop on VirGL/OpenGL

Open:

```bash
sudo nano /etc/environment
```

Preserve existing contents and add these two lines, with each setting appearing once:

```ini
MESA_LOADER_DRIVER_OVERRIDE=virtio_gpu
GSK_RENDERER=gl
```

Save with **Ctrl+O**, press **Enter**, then exit with **Ctrl+X**.

These settings select the VirtIO/VirGL driver for Mesa OpenGL and OpenGL rendering for GTK applications. Vulkan applications can still use Venus. This implements the desktop arrangement recommended for UTM 5.0.8. ([docs.mesa3d.org][7])

Now shut Ubuntu down completely:

```bash
sudo poweroff
```

## 5. Enable KosmicKrisp

With the VM stopped, return to **UTM → Settings → Display → QEMU Graphics Acceleration**:

| Setting              | Final value       |
| -------------------- | ----------------- |
| **Renderer Backend** | **ANGLE (Metal)** |
| **Vulkan Driver**    | **KosmicKrisp**   |
| **FPS Limit**        | **60**            |

Select **KosmicKrisp explicitly**: UTM’s default Vulkan driver is currently MoltenVK. ([UTM Documentation][3])

Start Ubuntu again. In Ubuntu’s **Settings → Displays**, begin with **1600 × 900 at 100% scale**.

## 6. Verify hardware graphics and run the Vulkan demo

First check OpenGL:

```bash
glxinfo -B
```

The renderer should contain **`virgl`**. A renderer showing only **`llvmpipe`** indicates software rendering.

Next, inspect Vulkan while explicitly selecting the VirtIO driver:

```bash
VK_LOADER_DRIVERS_SELECT='virtio*' vulkaninfo --summary
```

Look for:

```text
deviceName = Virtio-GPU Venus (...)
driverName = venus
```

**Venus is the expected guest driver name.** KosmicKrisp is the host driver selected in UTM, so its name need not appear literally in this output.

The temporary `VK_LOADER_DRIVERS_SELECT` filter selects the VirtIO driver’s manifest and prevents these tests from silently falling back to another Vulkan driver such as Lavapipe. ([GitHub][8])

Now launch the native Wayland demo:

```bash
VK_LOADER_DRIVERS_SELECT='virtio*' vkcube --wsi wayland
```

You should see an animated cube. **A Venus device report plus a successfully rendered cube** confirms both driver initialization and actual Vulkan rendering. Ubuntu 26.04’s Vulkan-tools package supports this Wayland command. ([GitHub][9])

## 7. Try a real Vulkan application

The earlier package command installed **mpv**. Start with a modest video file inside Ubuntu, replacing `/path/to/video.mp4` with its actual path:

```bash
VK_LOADER_DRIVERS_SELECT='virtio*' \
mpv --no-config --vo=gpu-next --gpu-api=vulkan \
    --gpu-context=waylandvk --hwdec=no -- /path/to/video.mp4
```

This uses **Vulkan for video rendering** and **the CPU for video decoding**. It is a practical graphics test without depending on virtualized hardware video decoding. ([mpv.io][10])

## 8. Keep the VM responsive

* **Keep Ubuntu’s swap enabled.** Inspect it with `swapon --show`; retain the installer-created swap rather than creating a duplicate automatically.
* **Keep roughly 10 GiB free inside Ubuntu** for package updates, caches and application data.
* **Start applications at 720p–1080p** with modest graphics settings.
* **Leave UTM’s generated GPU-memory settings alone.** If you see `hostmem=8G`, it describes a mapping window, not an extra 8 GiB of preallocated RAM. ([www.qemu.org][11])
* **Increase guest RAM to 8 GiB only when your actual workload needs it** and macOS still has memory headroom.

If the desktop breaks after enabling KosmicKrisp, stop the VM, temporarily set **Vulkan Driver → Disabled**, boot Ubuntu and recheck the two entries in `/etc/environment`.

If the cube works but a particular application fails, check that application’s ARM64 and Vulkan requirements. KosmicKrisp remains experimental in this UTM release; additional RAM cannot resolve every driver compatibility issue. ([UTM Documentation][3])

[1]: https://docs.getutm.app/guest-support/linux/ "Linux"
[2]: https://github.com/utmapp/UTM/releases/tag/v5.0.8 "Release v5.0.8 · utmapp/UTM"
[3]: https://docs.getutm.app/preferences/macos/ "macOS"
[4]: https://docs.getutm.app/settings-qemu/devices/display/ "Display"
[5]: https://ubuntu.com/desktop/docs/en/latest/tutorial/install-ubuntu-desktop/ "Install Ubuntu Desktop"
[6]: https://packages.ubuntu.com/resolute-updates/arm64/mesa-vulkan-drivers/filelist "Ubuntu – File list of package mesa-vulkan-drivers/resolute-updates/arm64"
[7]: https://docs.mesa3d.org/envvars.html "Environment Variables — The Mesa 3D Graphics Library latest documentation"
[8]: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDriverInterface.md "Vulkan-Loader/docs/LoaderDriverInterface.md at main · KhronosGroup/Vulkan-Loader"
[9]: https://github.com/KhronosGroup/Vulkan-Tools/blob/main/cube/cube.c "Vulkan-Tools/cube/cube.c at main · KhronosGroup/Vulkan-Tools"
[10]: https://mpv.io/manual/stable/ "https://mpv.io/manual/stable/"
[11]: https://www.qemu.org/docs/master/system/devices/virtio/virtio-gpu.html "VirtIO GPU"
