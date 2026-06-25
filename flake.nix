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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      purescript-overlay,
      pslua,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ purescript-overlay.overlays.default ];
        };
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        formatter = treefmtEval.config.build.wrapper;
        checks.formatting = treefmtEval.config.build.check self;
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            lua51Packages.lua
            lua51Packages.luacheck
            luaformatter
            nixfmt-rfc-style
            pslua.packages.${system}.default
            purs-bin.purs-0_15_16
            scriv
            spago-bin.spago-1_0_4
            treefmt
          ];
          # Robust pre-commit hook: point git at the tracked .githooks/ dir
          # (worktree/submodule-safe; never clobbers an existing .git/hooks).
          shellHook = "git config core.hooksPath .githooks";
        };
      }
    );

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
