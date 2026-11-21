# fzf.zsh

fzf-backed commands for zsh, with sensible fzf defaults. The plugin does nothing when `fzf` is not on `PATH`.

| Command | What it does |
| --- | --- |
| `fcd` | Change to a directory below the current one |
| `fcrecent` | Change to a directory from the stack or zoxide |
| `fdef` | Print the definition of an alias or function |
| `fe` | Open the selected files in the editor |
| `fenv` | Print the value of an exported variable |
| `ff` | Print the selected files |
| `fga` | Stage the selected changes |
| `fgalias` | Run a Git alias |
| `fgdel` | Delete the selected local branches |
| `fgfix` | Commit the staged changes as a fixup of a commit |
| `fgl` | Browse the commit log |
| `fgst` | Apply, pop, branch or drop a stash |
| `fgsw` | Switch to a local or remote branch |
| `fh` | Copy a command from the history |
| `fk` | Signal the selected processes |
| `fkp` | Terminate the processes listening on a port |
| `fman` | Open a manual page |
| `fmenu` | Pick and run an fzf-backed selector |
| `fp` | Change to a directory in PATH |
| `frg` | Search file contents and open the match |
| `fssh` | Connect to a literal host from SSH config and Include files |
| `ftail` | Follow a log file |

Options and keys:

| Command | Option or key |
| --- | --- |
| `fh` | `-p` prints the command instead of copying it |
| `fk` | `-s SIGNAL` sends that signal (default `TERM`) |
| `fgdel` | `-f` force-deletes with `git branch -D` |
| `fgl`, `fenv` | `ctrl-y` copies the hash or value |
| `fenv` | The preview hides values whose name contains TOKEN, KEY, SECRET, PASSWORD, PASSWD, CREDENTIAL or AUTH; enter still prints them |
| `fga`, `frg` | `ctrl-o` opens the file in the editor |
| `fgst` | `ctrl-a` apply, `ctrl-b` branch, `ctrl-p` pop, `del` drop |

On Linux, `fkp` uses `ss`, which only shows other users' processes when run as root.

`fmenu` lists the others and runs the one you pick. Completions for `fmenu` and `fdef` are included.

## Install

```sh
git clone https://github.com/devastion/fzf.zsh.git ~/.zsh/fzf.zsh
echo 'source ~/.zsh/fzf.zsh/fzf.plugin.zsh' >> ~/.zshrc
```

Load it before `compinit`, or run `compinit` afterwards, so the completions are found.

Needs fzf 0.38 or newer (`become`); the shell integration needs 0.48 (`fzf --zsh`) and is skipped on older versions. Its output is cached in `${XDG_CACHE_HOME:-~/.cache}/fzf.zsh` and refreshed when the fzf binary changes. Git commands need `git`. `fcrecent` uses `zoxide` when present. Previews use `eza`, `bat` or `lessfilter` when present, and `fd` replaces `find` for the default file list.

## Configuration

Set these before sourcing the plugin.

```zsh
zstyle ':fzf:' shell-integration no        # skip `fzf --zsh` (Ctrl-T, Ctrl-R, Alt-C)
zstyle ':fzf:' copy-command 'pbcopy'       # command that copies stdin to the clipboard
```

Without `copy-command`, the plugin uses `clipcopy` from [clipboard.zsh](https://github.com/devastion/clipboard.zsh) when its directory is on `fpath`, then `pbcopy`, `wl-copy` or `xclip`. Load clipboard.zsh first to get OSC 52 over SSH.

The plugin sets no `FZF_*` environment variables. Set `FZF_DEFAULT_OPTS`, `FZF_DEFAULT_COMMAND` and the `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS` and `FZF_CTRL_R_OPTS` variables yourself. The commands use `_fzf_clipcopy` for copy bindings, so keep `${_fzf_clipcopy}` in your own `ctrl-y` bindings if you want the same copy command.

## Testing

Tests use [ShellSpec](https://github.com/shellspec/shellspec) and run under zsh:

```sh
shellspec
```

## License

MIT
