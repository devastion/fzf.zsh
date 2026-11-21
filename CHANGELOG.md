# Changelog

## Unreleased

- The `fzf --zsh` integration is cached under `${XDG_CACHE_HOME:-~/.cache}/fzf.zsh` until the fzf binary changes, so a shell start no longer runs fzf twice.
- `fgsw` shows `git switch --track` errors instead of hiding them; `fgdel` sorts branches newest first like `fgsw`.
- `fgst` names the branch after the stash's base commit with `git rev-parse`, not by scanning the list line for hex digits.
- `fh` rejects unknown options; `fmenu` and its completion read the function headers once per session.
- `fdef` and `fmenu` no longer read every function body up front; previews read a file, so large `fpath`s open faster and big functions no longer hit `ARG_MAX`.
- `frg` skips the search while the query is empty.
- `fh` keeps multi-line history entries whole.
- The `fzf --zsh` integration is skipped on fzf older than 0.48.
- CI pins ShellSpec 0.28.1, runs on Linux and macOS, and checks syntax with `zsh -n`.
- `fssh` sorts hosts by byte value, so the order no longer depends on the locale.
- Specs cover every command, run previews and key bindings (stubbed, and through tmux with the real fzf), and exercise `fkp` against the real `ss` or `lsof`.
- fzf now runs previews, binds and reloads with `sh` whatever `$SHELL` is, so a fish or nushell login shell no longer breaks them.
- UI specs now also cover `fgfix`, `fk`, `ftail`, `fman` and `fssh`, and wait longer on CI (`UI_WAIT`).
- `fman` previews pages without `col` (not installed by default on Debian and Ubuntu).
