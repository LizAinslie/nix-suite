# User-global JS package-manager layout outside the Nix store.
# Covers npm (prefix + cache), yarn (cache + global), pnpm (home + store),
# and bun (install + cache). Puts their bin dirs on PATH.
# Does nothing until nix-suite.npm.enable = true.
#
# Call as: import ./npm-module.nix { kind = "nixos"; } args
#      or: import ./npm-module.nix { kind = "home-manager"; } args
{ kind }:
{ config, lib, ... }:

let
  cfg = config.nix-suite.npm;
  isAbsolute = p: lib.hasPrefix "/" p;

  # Shell expression: absolute paths stay literal; relative → $HOME/<path>.
  homeExpr =
    p: if isAbsolute p then lib.escapeShellArg p else "$HOME/${p}";

  # Concrete path for HM (needs homeDirectory).
  homePath =
    home: p: if isAbsolute p then p else "${home}/${p}";

  # --- resolved relative to options (for docs / npmrc on HM) ---
  paths = {
    npmPrefix = cfg.prefix;
    npmCache = cfg.cache;
    yarnCache = cfg.yarn.cache;
    yarnGlobal = cfg.yarn.global;
    pnpmHome = cfg.pnpm.home;
    pnpmStore = cfg.pnpm.store;
    bunInstall = cfg.bun.install;
    bunCache = cfg.bun.cache;
  };

  # Login/session env for NixOS (and shared mkdir list).
  extraInit = ''
    : "''${NPM_CONFIG_PREFIX:=${homeExpr paths.npmPrefix}}"
    : "''${NPM_CONFIG_CACHE:=${homeExpr paths.npmCache}}"
    export NPM_CONFIG_PREFIX NPM_CONFIG_CACHE
  ''
  + lib.optionalString cfg.yarn.enable ''
    : "''${YARN_CACHE_FOLDER:=${homeExpr paths.yarnCache}}"
    : "''${YARN_GLOBAL_FOLDER:=${homeExpr paths.yarnGlobal}}"
    export YARN_CACHE_FOLDER YARN_GLOBAL_FOLDER
  ''
  + lib.optionalString cfg.pnpm.enable ''
    : "''${PNPM_HOME:=${homeExpr paths.pnpmHome}}"
    : "''${npm_config_store_dir:=${homeExpr paths.pnpmStore}}"
    export PNPM_HOME npm_config_store_dir
  ''
  + lib.optionalString cfg.bun.enable ''
    : "''${BUN_INSTALL:=${homeExpr paths.bunInstall}}"
    : "''${BUN_INSTALL_CACHE_DIR:=${homeExpr paths.bunCache}}"
    export BUN_INSTALL BUN_INSTALL_CACHE_DIR
  ''
  + ''
    _nix_suite_npm_path_prepend() {
      case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
      esac
    }
    _nix_suite_npm_path_prepend "$NPM_CONFIG_PREFIX/bin"
  ''
  + lib.optionalString cfg.pnpm.enable ''
    _nix_suite_npm_path_prepend "$PNPM_HOME"
    _nix_suite_npm_path_prepend "$PNPM_HOME/bin"
  ''
  + lib.optionalString cfg.bun.enable ''
    _nix_suite_npm_path_prepend "$BUN_INSTALL/bin"
  ''
  + ''
    unset -f _nix_suite_npm_path_prepend
  '';

  fishExpr = p: if isAbsolute p then lib.escapeShellArg p else "$HOME/${p}";
  fishInit =
    ''
      set -q NPM_CONFIG_PREFIX; or set -gx NPM_CONFIG_PREFIX ${fishExpr paths.npmPrefix}
      set -q NPM_CONFIG_CACHE; or set -gx NPM_CONFIG_CACHE ${fishExpr paths.npmCache}
      mkdir -p $NPM_CONFIG_PREFIX/bin $NPM_CONFIG_CACHE 2>/dev/null
      fish_add_path -g $NPM_CONFIG_PREFIX/bin
    ''
    + lib.optionalString cfg.yarn.enable ''
      set -q YARN_CACHE_FOLDER; or set -gx YARN_CACHE_FOLDER ${fishExpr paths.yarnCache}
      set -q YARN_GLOBAL_FOLDER; or set -gx YARN_GLOBAL_FOLDER ${fishExpr paths.yarnGlobal}
    ''
    + lib.optionalString cfg.pnpm.enable ''
      set -q PNPM_HOME; or set -gx PNPM_HOME ${fishExpr paths.pnpmHome}
      set -q npm_config_store_dir; or set -gx npm_config_store_dir ${fishExpr paths.pnpmStore}
      mkdir -p $PNPM_HOME/bin $npm_config_store_dir 2>/dev/null
      fish_add_path -g $PNPM_HOME $PNPM_HOME/bin
    ''
    + lib.optionalString cfg.bun.enable ''
      set -q BUN_INSTALL; or set -gx BUN_INSTALL ${fishExpr paths.bunInstall}
      set -q BUN_INSTALL_CACHE_DIR; or set -gx BUN_INSTALL_CACHE_DIR ${fishExpr paths.bunCache}
      mkdir -p $BUN_INSTALL/bin $BUN_INSTALL_CACHE_DIR 2>/dev/null
      fish_add_path -g $BUN_INSTALL/bin
    '';

  mkdirExtraInit =
    let
      dirs = [
        "\"$NPM_CONFIG_PREFIX/bin\""
        "\"$NPM_CONFIG_CACHE\""
      ]
      ++ lib.optionals cfg.yarn.enable [
        "\"$YARN_CACHE_FOLDER\""
        "\"$YARN_GLOBAL_FOLDER\""
      ]
      ++ lib.optionals cfg.pnpm.enable [
        "\"$PNPM_HOME/bin\""
        "\"$npm_config_store_dir\""
      ]
      ++ lib.optionals cfg.bun.enable [
        "\"$BUN_INSTALL/bin\""
        "\"$BUN_INSTALL_CACHE_DIR\""
      ];
    in
    ''
      mkdir -p ${lib.concatStringsSep " " dirs} 2>/dev/null || true
    '';

  pmSubmodule =
    extra:
    lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Manage this package manager's user-global paths when nix-suite.npm.enable is on.";
        };
      }
      // extra;
    };
in
{
  options.nix-suite.npm = {
    enable = lib.mkEnableOption "user-global JS package-manager prefix/caches outside the Nix store (XDG layout)";

    prefix = lib.mkOption {
      type = lib.types.str;
      default = ".local/share/npm";
      description = "npm global prefix (bins under <prefix>/bin). Relative → $HOME.";
      example = ".npm-global";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = ".cache/npm";
      description = "npm cache (also used by npx). Relative → $HOME.";
    };

    yarn = lib.mkOption {
      type = pmSubmodule {
        cache = lib.mkOption {
          type = lib.types.str;
          default = ".cache/yarn";
          description = "YARN_CACHE_FOLDER. Relative → $HOME.";
        };
        global = lib.mkOption {
          type = lib.types.str;
          default = ".local/share/yarn";
          description = "YARN_GLOBAL_FOLDER (Yarn classic global packages). Relative → $HOME.";
        };
      };
      default = { };
      description = "Yarn cache + global folder.";
    };

    pnpm = lib.mkOption {
      type = pmSubmodule {
        home = lib.mkOption {
          type = lib.types.str;
          default = ".local/share/pnpm";
          description = "PNPM_HOME (global bins). Relative → $HOME.";
        };
        store = lib.mkOption {
          type = lib.types.str;
          default = ".local/share/pnpm/store";
          description = "pnpm content-addressable store (npm_config_store_dir). Relative → $HOME.";
        };
      };
      default = { };
      description = "pnpm home + store.";
    };

    bun = lib.mkOption {
      type = pmSubmodule {
        install = lib.mkOption {
          type = lib.types.str;
          default = ".local/share/bun";
          description = "BUN_INSTALL (global prefix; bins under <install>/bin). Relative → $HOME.";
        };
        cache = lib.mkOption {
          type = lib.types.str;
          default = ".cache/bun";
          description = "BUN_INSTALL_CACHE_DIR. Relative → $HOME.";
        };
      };
      default = { };
      description = "Bun install prefix + cache.";
    };

    writeNpmrc = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Write a managed npmrc: ~/.npmrc on home-manager (concrete paths +
        pnpm store-dir), or /etc/npmrc on NixOS (comment pointer; env wins).
      '';
    };

    ensureDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create prefix/bin, caches, and stores on activation / login.";
    };
  };

  config = lib.mkIf cfg.enable (
    if kind == "home-manager" then
      let
        home = config.home.homeDirectory;
        p = homePath home;
        npmPrefix = p paths.npmPrefix;
        npmCache = p paths.npmCache;
        yarnCache = p paths.yarnCache;
        yarnGlobal = p paths.yarnGlobal;
        pnpmHome = p paths.pnpmHome;
        pnpmStore = p paths.pnpmStore;
        bunInstall = p paths.bunInstall;
        bunCache = p paths.bunCache;

        sessionVars =
          {
            NPM_CONFIG_PREFIX = npmPrefix;
            NPM_CONFIG_CACHE = npmCache;
          }
          // lib.optionalAttrs cfg.yarn.enable {
            YARN_CACHE_FOLDER = yarnCache;
            YARN_GLOBAL_FOLDER = yarnGlobal;
          }
          // lib.optionalAttrs cfg.pnpm.enable {
            PNPM_HOME = pnpmHome;
            npm_config_store_dir = pnpmStore;
          }
          // lib.optionalAttrs cfg.bun.enable {
            BUN_INSTALL = bunInstall;
            BUN_INSTALL_CACHE_DIR = bunCache;
          };

        sessionPath =
          [ "${npmPrefix}/bin" ]
          ++ lib.optionals cfg.pnpm.enable [
            pnpmHome
            "${pnpmHome}/bin"
          ]
          ++ lib.optional cfg.bun.enable "${bunInstall}/bin";

        mkdirArgs = lib.escapeShellArgs (
          [
            "${npmPrefix}/bin"
            npmCache
          ]
          ++ lib.optionals cfg.yarn.enable [
            yarnCache
            yarnGlobal
          ]
          ++ lib.optionals cfg.pnpm.enable [
            "${pnpmHome}/bin"
            pnpmStore
          ]
          ++ lib.optionals cfg.bun.enable [
            "${bunInstall}/bin"
            bunCache
          ]
        );

        npmrc =
          ''
            ; managed by nix-suite.npm — do not point these at the Nix store
            prefix=${npmPrefix}
            cache=${npmCache}
          ''
          + lib.optionalString cfg.pnpm.enable ''
            store-dir=${pnpmStore}
          '';
      in
      lib.mkMerge [
        {
          home.sessionVariables = sessionVars;
          home.sessionPath = sessionPath;
        }
        (lib.mkIf cfg.writeNpmrc { home.file.".npmrc".text = npmrc; })
        (lib.mkIf cfg.ensureDirs {
          home.activation.nix-suite-npm-dirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p ${mkdirArgs}
          '';
        })
      ]
    else
      lib.mkMerge [
        { environment.extraInit = extraInit; }
        (lib.mkIf config.programs.fish.enable {
          programs.fish.shellInit = fishInit;
        })
        (lib.mkIf cfg.writeNpmrc {
          environment.etc."npmrc".text = ''
            ; managed by nix-suite.npm
            ; paths come from environment (NPM_CONFIG_*, YARN_*, PNPM_*, BUN_*)
            ; npm:    $HOME/${paths.npmPrefix}  /  $HOME/${paths.npmCache}
            ; yarn:   $HOME/${paths.yarnCache}  /  $HOME/${paths.yarnGlobal}
            ; pnpm:   $HOME/${paths.pnpmHome}   /  $HOME/${paths.pnpmStore}
            ; bun:    $HOME/${paths.bunInstall} /  $HOME/${paths.bunCache}
          '';
        })
        (lib.mkIf cfg.ensureDirs {
          environment.extraInit = lib.mkAfter mkdirExtraInit;
        })
      ]
  );
}
