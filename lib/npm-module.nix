# User-global npm layout that never writes into the Nix store.
# Sets NPM_CONFIG_PREFIX / NPM_CONFIG_CACHE and puts <prefix>/bin on PATH.
# Does nothing until nix-suite.npm.enable = true.
#
# Call as: import ./npm-module.nix { kind = "nixos"; } args
#      or: import ./npm-module.nix { kind = "home-manager"; } args
{ kind }:
{ config, lib, ... }:

let
  cfg = config.nix-suite.npm;
  isAbsolute = p: lib.hasPrefix "/" p;

  prefixExpr =
    if isAbsolute cfg.prefix then lib.escapeShellArg cfg.prefix else "$HOME/${cfg.prefix}";
  cacheExpr =
    if isAbsolute cfg.cache then lib.escapeShellArg cfg.cache else "$HOME/${cfg.cache}";

  extraInit = ''
    : "''${NPM_CONFIG_PREFIX:=${prefixExpr}}"
    : "''${NPM_CONFIG_CACHE:=${cacheExpr}}"
    export NPM_CONFIG_PREFIX NPM_CONFIG_CACHE
    case ":$PATH:" in
      *":$NPM_CONFIG_PREFIX/bin:"*) ;;
      *) export PATH="$NPM_CONFIG_PREFIX/bin:$PATH" ;;
    esac
  '';
in
{
  options.nix-suite.npm = {
    enable = lib.mkEnableOption "user-global npm prefix/cache outside the Nix store (XDG layout)";

    prefix = lib.mkOption {
      type = lib.types.str;
      default = ".local/share/npm";
      description = ''
        npm global prefix (global installs and their bins). Relative paths are
        under $HOME. Absolute paths are used as-is. Default follows XDG data.
      '';
      example = ".npm-global";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = ".cache/npm";
      description = ''
        npm cache directory. Relative paths are under $HOME. Absolute paths
        are used as-is. Default follows XDG cache.
      '';
    };

    writeNpmrc = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Write a managed npmrc: ~/.npmrc on home-manager (with concrete paths),
        or /etc/npmrc on NixOS (comment pointer; real values come from env).
      '';
    };

    ensureDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create prefix, prefix/bin, and cache on activation / login.";
    };
  };

  config = lib.mkIf cfg.enable (
    if kind == "home-manager" then
      let
        prefixPath =
          if isAbsolute cfg.prefix then cfg.prefix else "${config.home.homeDirectory}/${cfg.prefix}";
        cachePath =
          if isAbsolute cfg.cache then cfg.cache else "${config.home.homeDirectory}/${cfg.cache}";
      in
      lib.mkMerge [
        {
          home.sessionVariables = {
            NPM_CONFIG_PREFIX = prefixPath;
            NPM_CONFIG_CACHE = cachePath;
          };
          home.sessionPath = [ "${prefixPath}/bin" ];
        }
        (lib.mkIf cfg.writeNpmrc {
          home.file.".npmrc".text = ''
            ; managed by nix-suite.npm — do not point prefix at the Nix store
            prefix=${prefixPath}
            cache=${cachePath}
          '';
        })
        (lib.mkIf cfg.ensureDirs {
          home.activation.nix-suite-npm-dirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg "${prefixPath}/bin"} \
              ${lib.escapeShellArg cachePath}
          '';
        })
      ]
    else
      lib.mkMerge [
        { environment.extraInit = extraInit; }
        (lib.mkIf cfg.writeNpmrc {
          environment.etc."npmrc".text = ''
            ; managed by nix-suite.npm
            ; prefix/cache come from NPM_CONFIG_PREFIX / NPM_CONFIG_CACHE
            ; (default: $HOME/${cfg.prefix} and $HOME/${cfg.cache})
          '';
        })
        (lib.mkIf cfg.ensureDirs {
          environment.extraInit = lib.mkAfter ''
            mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_CACHE" 2>/dev/null || true
          '';
        })
      ]
  );
}
