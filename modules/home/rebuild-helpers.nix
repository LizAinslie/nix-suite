# In home-manager the host defaults to the NixOS hostName when HM runs as a
# NixOS module (osConfig is passed in), otherwise null (nixos-rebuild then
# picks the attribute named after the hostname at run time).
{ lib, ... }@args:
import ../../lib/rebuild-helpers-module.nix {
  hostDefault = if args ? osConfig then args.osConfig.networking.hostName else null;
  hostDefaultText = lib.literalMD "`osConfig.networking.hostName` under NixOS, else `null`";
} args
