# Every nix-suite NixOS tool. Importing this changes nothing until a tool's
# nix-suite.<tool>.enable is set.
{
  imports = [
    ./crypt-keeper.nix
    ./gc.nix
    ./nvd-diff.nix
    ./rebuild-helpers.nix
    ./shell.nix
  ];
}
