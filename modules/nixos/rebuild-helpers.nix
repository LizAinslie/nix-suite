{ config, lib, ... }@args:
import ../../lib/rebuild-helpers-module.nix {
  hostDefault = config.networking.hostName;
  hostDefaultText = lib.literalExpression "config.networking.hostName";
} args
