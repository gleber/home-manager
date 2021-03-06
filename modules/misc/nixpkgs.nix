# Adapted from Nixpkgs.

{ config, lib, pkgs, ... }:

with lib;

let

  isConfig = x:
    builtins.isAttrs x || builtins.isFunction x;

  optCall = f: x:
    if builtins.isFunction f
    then f x
    else f;

  mergeConfig = lhs_: rhs_:
    let
      lhs = optCall lhs_ { inherit pkgs; };
      rhs = optCall rhs_ { inherit pkgs; };
    in
    lhs // rhs //
    optionalAttrs (lhs ? packageOverrides) {
      packageOverrides = pkgs:
        optCall lhs.packageOverrides pkgs //
        optCall (attrByPath ["packageOverrides"] ({}) rhs) pkgs;
    } //
    optionalAttrs (lhs ? perlPackageOverrides) {
      perlPackageOverrides = pkgs:
        optCall lhs.perlPackageOverrides pkgs //
        optCall (attrByPath ["perlPackageOverrides"] ({}) rhs) pkgs;
    };

  configType = mkOptionType {
    name = "nixpkgs-config";
    description = "nixpkgs config";
    check = traceValIfNot isConfig;
    merge = args: fold (def: mergeConfig def.value) {};
  };

  overlayType = mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = builtins.isFunction;
    merge = lib.mergeOneOption;
  };

  _pkgs = import <nixpkgs> (
    filterAttrs (n: v: v != null) config.nixpkgs
  );

in

{
  options.nixpkgs = {
    config = mkOption {
      default = null;
      example = { allowBroken = true; };
      type = types.nullOr configType;
      description = ''
        The configuration of the Nix Packages collection. (For
        details, see the Nixpkgs documentation.) It allows you to set
        package configuration options.
        </para><para>
        If <literal>null</literal>, then configuration is taken from
        the fallback location, for example,
        <filename>~/.config/nixpkgs/config.nix</filename>.
      '';
    };

    overlays = mkOption {
      default = null;
      example = literalExample
        ''
          [ (self: super: {
              openssh = super.openssh.override {
                hpnSupport = true;
                withKerberos = true;
                kerberos = self.libkrb5;
              };
            };
          ) ]
        '';
      type = types.nullOr (types.listOf overlayType);
      description = ''
        List of overlays to use with the Nix Packages collection. (For
        details, see the Nixpkgs documentation.) It allows you to
        override packages globally. This is a function that takes as
        an argument the <emphasis>original</emphasis> Nixpkgs. The
        first argument should be used for finding dependencies, and
        the second should be used for overriding recipes.
        </para><para>
        If <literal>null</literal>, then the overlays are taken from
        the fallback location, for example,
        <filename>~/.config/nixpkgs/overlays</filename>.
      '';
    };

    system = mkOption {
      type = types.str;
      example = "i686-linux";
      internal = true;
      description = ''
        Specifies the Nix platform type for which the user environment
        should be built. If unset, it defaults to the platform type of
        your host system. Specifying this option is useful when doing
        distributed multi-platform deployment, or when building
        virtual machines.
      '';
    };
  };

  config = {
    _module.args = {
      pkgs = _pkgs;
      pkgs_i686 = _pkgs.pkgsi686Linux;
    };
  };
}
