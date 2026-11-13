# nix-suite

Small NixOS and home-manager tools that I share between my flakes. Each one
sits behind its own `nix-suite.<tool>.enable` switch, and every switch
defaults to off. Importing the modules changes nothing until you turn a tool
on. The flake check verifies that.

The only input is `nixpkgs`.

## Use it

```nix
# flake.nix
inputs.nix-suite = {
  url = "github:LizAinslie/nix-suite";
  inputs.nixpkgs.follows = "nixpkgs";
};

# a NixOS module
{ inputs, ... }: {
  imports = [ inputs.nix-suite.nixosModules.default ];
  nix-suite.rebuild-helpers.enable = true;   # nrs / nfu / nadd
}

# a home-manager module
{ inputs, ... }: {
  imports = [ inputs.nix-suite.homeModules.default ];
  nix-suite.crypt-keeper = {
    enable = true;
    drives = [ { alias = "dev"; uuid = "<crypto_LUKS uuid>"; mountPoint = "/mnt/dev"; } ];
  };
}
```

You can also import a single tool, like `nixosModules.gc` or
`homeModules.crypt-keeper`. `homeManagerModules` is an alias for `homeModules`.

## Tools

| tool | NixOS | home-manager | what it does |
|---|---|---|---|
| `shell` | yes | yes | Fish-first helpers: enables `fish`, installs `desktop-file-utils`, and adds `ll` / `la` / `udb` (refresh `.desktop` DBs + restart Vicinae). Fish gets abbreviations; bash/zsh get aliases. |
| `npm` | yes | yes | User-global JS layout outside the Nix store: npm prefix/cache, yarn cache/global, pnpm home/store, bun install/cache; their bin dirs on `PATH`; dirs created on login/activation. |
| `rebuild-helpers` | yes | yes | Shell shortcuts for a flake checkout: `nrs` runs `sudo nixos-rebuild switch --flake <flake>#<host>`, `nfu` runs `nix flake update <flake>`, and `nadd` runs `git -C <flake> add .`. Fish gets abbreviations, and bash and zsh get aliases, but only for the shells you have enabled. |
| `crypt-keeper` | yes | yes | `crypt-keeper open\|close <alias>` unlocks a LUKS drive and mounts it, or unmounts it and locks it again, using a declarative drive table. |
| `nvd-diff` | yes | – | Prints an [nvd](https://git.sr.ht/~khumba/nvd) package diff (added, removed, and changed versions) on every system activation. |
| `gc` | yes | – | Runs `nix.gc` and `nix.optimise` automatically, weekly by default, keeping 14 days of generations. Every value uses `mkDefault`, so your host's own settings win. |

### shell

```nix
nix-suite.shell.enable = true;   # fish + ll / la / udb
# udb expands to: update-desktop-database … ; systemctl --user try-restart vicinae
```

### npm

```nix
nix-suite.npm.enable = true;
# defaults (all under $HOME), each PM can be turned off on its own:
#   npm:  prefix=.local/share/npm   cache=.cache/npm
#   yarn: cache=.cache/yarn         global=.local/share/yarn
#   pnpm: home=.local/share/pnpm    store=.local/share/pnpm/store
#   bun:  install=.local/share/bun  cache=.cache/bun
# then: npm i -g @kilocode/cli   # → ~/.local/share/npm, not the store
#       pnpm add -g … / yarn global add … / bun add -g … use the same layout
```

### rebuild-helpers

```nix
nix-suite.rebuild-helpers = {
  enable = true;
  flake = "/etc/nixos";            # default
  host = "myhost";                 # NixOS default: networking.hostName
                                   # HM default: osConfig hostName, or null (no #host)
  nrs.action = "switch";           # or "boot" / "test"
  nfu.enable = false;              # each shortcut can be turned off on its own
};
```

### crypt-keeper

```nix
nix-suite.crypt-keeper = {
  enable = true;
  drives = [
    {
      alias = "dev";
      uuid = "8f47fc38-...";             # the crypto_LUKS UUID (lsblk -f)
      mountPoint = "/mnt/dev";
      extraMountOptions = [ "noexec" ];  # appended to compress=zstd,nodev,nosuid
    }
  ];
};
```

`crypt-keeper open dev` runs `cryptsetup open` to create `/dev/mapper/cryptdev`,
creates the mount point if needed, and mounts it. `crypt-keeper close dev`
reverses both steps. It uses `sudo`, and `cryptsetup` must be on your PATH.
The baseline options assume btrfs (`compress=zstd`).

### nvd-diff

```nix
nix-suite.nvd-diff.enable = true;
```

### gc

```nix
nix-suite.gc = { enable = true; dates = "weekly"; keepDays = 14; optimise = true; };
```

## License

MIT
