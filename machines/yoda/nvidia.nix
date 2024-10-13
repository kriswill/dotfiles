{ config, pkgs, ... }:
let
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/default.nix

  # driver_555_58_02 = config.boot.kernelPackages.nvidiaPackages.mkDriver {
  #   version = "555.58.02";
  #   sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
  #   sha256_aarch64 = "sha256-wb20isMrRg8PeQBU96lWJzBMkjfySAUaqt4EgZnhyF8=";
  #   openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
  #   settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
  #   persistencedSha256 = "sha256-a1D7ZZmcKFWfPjjH1REqPM5j/YLWKnbkP9qfRyIyxAw=";
  # };
  nvidiaDriver = config.boot.kernelPackages.nvidiaPackages.stable;
in
# doesn't compile 2024/07/29
{
  services.xserver.videoDrivers = [ "nvidia" ];
  # Enable OpenGL

  hardware = {
    nvidia = {
      package = nvidiaDriver;
      # Modesetting is needed most of the time
      modesetting.enable = true;

      # Enable power management (do not disable this unless you have a reason to).
      # Likely to cause problems on laptops and with screen tearing if disabled.
      powerManagement.enable = false;

      # Use the NVidia open source kernel module (which isn't “nouveau”).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      open = true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;
    };

    opengl = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    # unstable only
    # graphics = {
    #   # in https://github.com/lutris/docs/blob/master/InstallingDrivers.md#renderer-configuration-opengl-vulkan
    #   extraPackages = with pkgs; [
    #     rocm-opencl-icd
    #     rocm-opencl-runtime
    #   ];
    #   enable = true;
    #   enable32Bit = true;
    # };
  };

  boot = {
    initrd.kernelModules = [ "nvidia" ];
    blacklistedKernelModules = [ "nouveau" ];
    extraModulePackages = [ nvidiaDriver ];
    kernelParams = [
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];
  };

  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "va_gl";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_MaxFramesAllowed = "0";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  environment.systemPackages = with pkgs; [ egl-wayland ];
}
