{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  # Nix — RFC 166 formatter.
  programs.nixfmt.enable = true;

  # PureScript — purs-tidy is not a first-class treefmt program, so wire it via
  # the generic mechanism. It picks up `.tidyrc.json` from the project root.
  settings.formatter.purs-tidy = {
    command = "${pkgs.purs-tidy}/bin/purs-tidy";
    options = [ "format-in-place" ];
    includes = [ "*.purs" ];
  };

  # Lua FFI — LuaFormatter keeps the parentheses pslua's foreign-file parser
  # requires (unlike StyLua, which strips them). Config in `.lua-format`.
  settings.formatter.lua-format = {
    command = "${pkgs.luaformatter}/bin/lua-format";
    options = [
      "-i"
      "-c"
      ".lua-format"
    ];
    includes = [ "*.lua" ];
  };

  # Never format generated output or vendored trees.
  settings.global.excludes = [
    "dist/*"
    "output/*"
    ".spago/*"
    "node_modules/*"
    "*.lock"
    "flake.lock"
    "spago.lock"
    ".tidyrc.json"
    ".lua-format"
  ];
}
