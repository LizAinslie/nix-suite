# Module body for crypt-keeper, shared by the NixOS and home-manager variants.
# `installTo` is the option path the script lands in:
#   NixOS: [ "environment" "systemPackages" ]   home-manager: [ "home" "packages" ]
installTo:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.nix-suite.crypt-keeper;

  driveModule = types.submodule {
    options = {
      alias = mkOption {
        type = types.str;
        description = "Short identifier.";
      };
      uuid = mkOption {
        type = types.str;
        description = "The crypto_LUKS UUID.";
      };
      mountPoint = mkOption {
        type = types.str;
        description = "Target directory path.";
      };
      extraMountOptions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional mount flags (e.g., [ \"noexec\" ]) appended to the baseline.";
      };
    };
  };
in
{
  options.nix-suite.crypt-keeper = {
    enable = mkEnableOption "crypt-keeper, an on-demand LUKS open+mount / umount+close helper";
    drives = mkOption {
      type = types.listOf driveModule;
      default = [ ];
      description = ''
        Declarative table of your encrypted drives. Each one is mounted with
        the baseline options compress=zstd,nodev,nosuid plus extraMountOptions.
      '';
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = import ./crypt-keeper.nix { inherit lib pkgs; } cfg.drives;
      defaultText = literalMD "the generated `crypt-keeper` script";
      description = "The generated script (read-only, for referencing elsewhere).";
    };
  };

  config = mkIf cfg.enable (setAttrByPath installTo [ cfg.package ]);
}
