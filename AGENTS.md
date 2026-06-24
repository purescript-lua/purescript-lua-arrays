# AGENTS.md

A PureScript→Lua FFI fork in the [`purescript-lua`](https://github.com/purescript-lua/purescript-lua) package set. Generated code targets **Lua 5.1**.

## Commands

- Build: `nix develop -c ./scripts/build`
- Test: `nix develop -c bash ./scripts/test` (only forks that ship Lua regression tests have one)
- Lint: `nix develop -c luacheck --quiet --std lua51 --no-unused-args --max-line-length 130 src/`
- Format: `nix fmt` (check: `nix fmt && git diff --exit-code`)

## Formatting

`nix fmt` runs treefmt (`treefmt.nix`): nixfmt for Nix, purs-tidy
for `*.purs` (config in `.tidyrc.json`), and LuaFormatter for the `*.lua` FFI
(config in `.lua-format`). LuaFormatter is used over StyLua because it keeps the
parentheses pslua's foreign-file parser requires. The Lua line budget is 130
columns, matching the `luacheck --max-line-length` above. The check is
content-based (`nix fmt && git diff --exit-code`) rather than `treefmt --ci`,
since the in-place formatters bump mtime even when content is unchanged, which
trips treefmt's `--fail-on-change`. CI and the pre-commit hook use it.

## Lua 5.1 target

The output runs on Lua 5.1, which is stricter than 5.3:

- No `table.unpack`, `bit32`, `utf8`, or the `//` operator. `math.pow` and `math.atan2` do exist.
- Array-style tables are 1-indexed: the first element is `t[1]`, not `t[0]`.
- `unit` is `{}`, never `nil`: a `nil` table element silently disappears, which would collapse `Array Unit` into an empty table.
- Lua 5.1 mangles some Lua 5.3 string escapes, so keep FFI string escapes 5.1-safe.

## FFI files (`src/*.lua`)

pslua's foreign-file parser needs every exported value wrapped in parentheses:

```lua
return {
  identity = (function(x) return x end),
  answer = (42),
}
```

A bare `function … end` or an unparenthesised expression fails to parse.

## Toolchain

`flake.nix` pins everything through [`purescript-overlay`](https://github.com/thomashoneyman/purescript-overlay): purs 0.15.16 (`purs-bin.purs-0_15_16`), spago 1.x (`spago-bin.spago-1_0_4`), Lua 5.1 (`lua51Packages`). The `pslua` input tracks `github:purescript-lua/purescript-lua`; keep `flake.lock` reasonably current, since a long-stale pslua pin won't create the `--lua-output-file` directory and CI fails.

## Releasing

Tag-driven, with no GitHub Release or changelog entry. The full conventions live in the [package-set repo](https://github.com/purescript-lua/purescript-lua-package-sets/blob/master/CONTRIBUTING.md): push an annotated tag on `master`, bump this fork's `version` in the package set's `src/packages.json`, refresh `latest-compatible-sets.json`, and push a `psc-*` set tag.
