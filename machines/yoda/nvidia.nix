{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  # Enable OpenGL

  hardware = {
    nvidia = {
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

      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "550.107.02";
        sha256_64bit = "sha256-+XwcpN8wYCjYjHrtYx+oBhtVxXxMI02FO1ddjM5sAWg=";
        sha256_aarch64 = "sha256-mVEeFWHOFyhl3TGx1xy5EhnIS/nRMooQ3+LdyGe69TQ=";
        openSha256 = "sha256-Po+pASZdBaNDeu5h8sgYgP9YyFAm9ywf/8iyyAaLm+w=";
        settingsSha256 = "sha256-WFZhQZB6zL9d5MUChl2kCKQ1q9SgD0JlP4CMXEwp2jE=";
        persistencedSha256 = "sha256-Vz33gNYapQ4++hMqH3zBB4MyjxLxwasvLzUJsCcyY4k=";
      };
      
      # NOTE: issues with this driver in Hyprland - flickering
      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      # 555.58.02 - https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/default.nix
      # package = config.boot.kernelPackages.nvidiaPackages.latest;
      # package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      #   version = "555.58.02";
      #   sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
      #   sha256_aarch64 = "sha256-wb20isMrRg8PeQBU96lWJzBMkjfySAUaqt4EgZnhyF8=";
      #   openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
      #   settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
      #   persistencedSha256 = "sha256-a1D7ZZmcKFWfPjjH1REqPM5j/YLWKnbkP9qfRyIyxAw=";
      # };

      # package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      #   version = "560.28.03";
      #   sha256_64bit = "sha256-martv18vngYBJw1IFUCAaYr+uc65KtlHAMdLMdtQJ+Y=";
      #   sha256_aarch64 = "sha256-+u0ZolZcZoej4nqPGmZn5qpyynLvu2QSm9Rd3wLdDmM=";
      #   openSha256 = "sha256-asGpqOpU0tIO9QqceA8XRn5L27OiBFuI9RZ1NjSVwaM=";
      #   settingsSha256 = "sha256-b4nhUMCzZc3VANnNb0rmcEH6H7SK2D5eZIplgPV59c8=";
      #   persistencedSha256 = "sha256-MhITuC8tH/IPhCOUm60SrPOldOpitk78mH0rg+egkTE=";
      # };
    };

    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
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
    initrd.kernelModules = ["nvidia"];
    blacklistedKernelModules = ["nouveau"];
    kernelParams = [
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];
  };
  
  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_MaxFramesAllowed = "0";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  environment.systemPackages = with pkgs; [
    vaapiVdpau
    egl-wayland
  ];
}
