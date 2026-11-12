# Weekly garbage collection + store optimisation with conservative defaults.
# Everything is set with mkDefault, so a host's own nix.gc.* wins.
{ config, lib, ... }:

let
  cfg = config.nix-suite.gc;
in
{
  options.nix-suite.gc = {
    enable = lib.mkEnableOption "automatic nix garbage collection and store optimisation";
    dates = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd calendar expression for both GC and optimise.";
    };
    keepDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "GC deletes generations older than this many days.";
    };
    optimise = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Also run `nix-store --optimise` (hard-link duplicate files) on the same schedule.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault cfg.dates;
      options = lib.mkDefault "--delete-older-than ${toString cfg.keepDays}d";
    };
    nix.optimise = lib.mkIf cfg.optimise {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault [ cfg.dates ];
    };
  };
}
