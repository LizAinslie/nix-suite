# Module body for rebuild-helpers (nrs / nfu / nadd), shared by the NixOS and
# home-manager variants. Both expose the same options; they only differ in
# where the shell shortcuts are written and what `host` defaults to.
#
# Fish gets abbreviations (expand in place, like the originals); bash and zsh
# get aliases. Each shell is only touched if that shell's module is enabled.
{ hostDefault, hostDefaultText }:

{ config, lib, ... }:

let
  cfg = config.nix-suite.rebuild-helpers;

  target = if cfg.host == null then cfg.flake else "${cfg.flake}#${cfg.host}";

  commands =
    lib.optionalAttrs cfg.nrs.enable { nrs = "sudo nixos-rebuild ${cfg.nrs.action} --flake ${target}"; }
    // lib.optionalAttrs cfg.nfu.enable { nfu = "nix flake update ${cfg.flake}"; }
    // lib.optionalAttrs cfg.nadd.enable { nadd = "git -C ${cfg.flake} add ."; };

  sub = name: description: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add `${name}` (${description}) when rebuild-helpers is enabled.";
    };
  };
in
{
  options.nix-suite.rebuild-helpers = {
    enable = lib.mkEnableOption "the nrs / nfu / nadd shell shortcuts for a flake checkout";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Path to the flake checkout the shortcuts act on.";
    };

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = hostDefault;
      defaultText = hostDefaultText;
      description = ''
        nixosConfigurations attribute `nrs` switches to. null leaves off the
        `#host` part, so nixos-rebuild picks the attribute named after the
        machine's hostname at run time.
      '';
    };

    nrs = sub "nrs" "sudo nixos-rebuild <action> --flake <flake>#<host>" // {
      action = lib.mkOption {
        type = lib.types.enum [
          "switch"
          "boot"
          "test"
        ];
        default = "switch";
        description = "nixos-rebuild action `nrs` runs.";
      };
    };
    nfu = sub "nfu" "nix flake update <flake>";
    nadd = sub "nadd" "git -C <flake> add .";

    commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = commands;
      description = "The resulting name -> command table (read-only).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf config.programs.fish.enable { programs.fish.shellAbbrs = commands; })
      (lib.mkIf config.programs.zsh.enable { programs.zsh.shellAliases = commands; })
      # NixOS has no programs.bash.enable switch (bash is always there);
      # home-manager does.
      (lib.mkIf (config.programs.bash.enable or true) { programs.bash.shellAliases = commands; })
    ]
  );
}
