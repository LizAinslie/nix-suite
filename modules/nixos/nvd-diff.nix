# Print what changed (package versions added / removed / bumped) every time a
# new system generation is activated, using nvd. Runs on switch, boot entries
# being made active, and `nixos-rebuild dry-activate`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nix-suite.nvd-diff;
in
{
  options.nix-suite.nvd-diff = {
    enable = lib.mkEnableOption "an nvd package diff printed on every system activation";
    package = lib.mkPackageOption pkgs "nvd" { };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.nix-suite-nvd-diff = {
      supportsDryActivation = true;
      text = ''
        if [[ -e /run/current-system ]]; then
          echo "--- nvd: /run/current-system -> $systemConfig"
          ${lib.getExe cfg.package} --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "$systemConfig" || true
        fi
      '';
    };
  };
}
