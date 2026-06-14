let upstream-ps =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20240320/packages.dhall
        sha256:ae8a25645e81ff979beb397a21e5d272fae7c9ebdb021a96b1b431388c8f3c34

let upstream-lua =
      https://github.com/purescript-lua/purescript-lua-package-sets/releases/download/psc-0.15.15-20240338/packages.dhall
        sha256:8a7527f82c9a8a9ec2c1c945bf45a75faa4bf847609b8ada570c1cd969bca7eb

in  upstream-ps // upstream-lua
