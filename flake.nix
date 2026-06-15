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
          # Install a content-based pre-commit hook. It compares the working
          # tree diff before and after `nix fmt`, so it only objects to changes
          # the formatter itself introduces (not the developer's existing
          # unstaged work) and is not fooled by formatters that only bump mtime.
          # Rewritten each shell entry to stay in sync with this flake.
          shellHook = ''
            hook=.git/hooks/pre-commit
            if [ -d .git ]; then
              printf '%s\n' \
                '#!/usr/bin/env bash' \
                'before=$(git diff)' \
                'nix fmt >/dev/null 2>&1 || exit 0' \
                '[ "$before" = "$(git diff)" ] || { echo "nix fmt changed files; re-stage them, then commit." >&2; exit 1; }' \
                > "$hook"
              chmod +x "$hook"
            fi
          '';
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
