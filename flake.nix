{
  description = "Purescript-Lua Flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    purescript-overlay = {
      url = "github:thomashoneyman/purescript-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pslua.url = "github:purescript-lua/purescript-lua";
  };

  outputs = { self, nixpkgs, flake-utils, purescript-overlay, pslua }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ purescript-overlay.overlays.default ];
        };
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            dhall
            lua51Packages.lua
            lua51Packages.luacheck
            luaformatter
            nixfmt-rfc-style
            pslua.packages.${system}.default
            purs-bin.purs-0_15_16
            spago-bin.spago-0_21_0
            treefmt
          ];
        };
      });

  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://purescript-lua.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "purescript-lua.cachix.org-1:yLs4ei2HtnuPtzLekOrW3xdfm95+Etw15gwgyIGTayA="
    ];
  };
}
