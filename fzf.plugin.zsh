0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

((${+commands[fzf]})) || return 0

typeset -g _fzf_dir="${0:h}"
((${fpath[(Ie)${_fzf_dir}/functions]})) || fpath=("${_fzf_dir}/functions" $fpath)
((${fpath[(Ie)${_fzf_dir}/completions]})) || fpath=("${_fzf_dir}/completions" $fpath)
autoload -Uz -- "${_fzf_dir}"/functions/*(N:t)

# After compinit, fpath is no longer scanned: register the completions by hand.
if ((${+functions[compdef]})); then
  () {
    local file line
    for file in "${_fzf_dir}"/completions/_*(N-.); do
      IFS= read -r line < "${file}"
      [[ "${line}" == '#compdef '* ]] || continue
      autoload -Uz -- "${file:t}"
      compdef "${file:t}" ${=line#\#compdef }
    done
  }
fi

[[ -z "${FZF_DEFAULT_OPTS_FILE-}" || -r "${FZF_DEFAULT_OPTS_FILE}" ]] || unset FZF_DEFAULT_OPTS_FILE

# `fzf --zsh` needs fzf 0.48 or newer. Its output is cached until the fzf
# binary changes, so a shell start does not run fzf twice.
if [[ -o zle && -z "${ZSH_EXECUTION_STRING-}" ]] && zstyle -T ':fzf:' shell-integration; then
  () {
    zmodload -F zsh/stat b:zstat
    autoload -Uz is-at-least
    local -A stat_info
    local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/fzf.zsh" cache version
    # The resolved path is part of the key: a Nix store file has a fixed mtime.
    local binary="${commands[fzf]:A}"
    zstat -H stat_info -- "${binary}" 2> /dev/null || stat_info=(mtime 0 size 0)
    cache="${cache_dir}/integration-${binary//[^A-Za-z0-9]/_}-${stat_info[mtime]}-${stat_info[size]}.zsh"
    if [[ ! -s "${cache}" ]]; then
      version="${${(z)$(fzf --version 2> /dev/null)}[1]}"
      is-at-least 0.48 "${version%%[^0-9.]*}" || return 0
      command mkdir -p -- "${cache_dir}" 2> /dev/null
      command rm -f -- "${cache_dir}"/integration-*.zsh(N) 2> /dev/null
      if fzf --zsh >| "${cache}.$$" 2> /dev/null && command mv -f -- "${cache}.$$" "${cache}"; then
        :
      else
        command rm -f -- "${cache}.$$" 2> /dev/null
        source <(fzf --zsh)
        return
      fi
    fi
    [[ -s "${cache}" ]] && source "${cache}"
  }
fi

() {
  local command_line clipcopy_file
  zstyle -s ':fzf:' copy-command command_line
  if [[ -z "${command_line}" ]]; then
    clipcopy_file=(${^fpath}/clipcopy(N[1]))
    if ((${#clipcopy_file})); then
      command_line="fpath=(${(q)${clipcopy_file[1]:h}}); autoload -Uz clipcopy _clipboard_detect_backend; clipcopy"
      command_line="zsh -f -c ${(q)command_line}"
    elif ((${+commands[pbcopy]})); then
      command_line='pbcopy'
    elif ((${+commands[wl-copy]})); then
      command_line='wl-copy'
    elif ((${+commands[xclip]})); then
      command_line='xclip -selection clipboard -in'
    else
      command_line='cat > /dev/null'
    fi
  fi
  typeset -g _fzf_clipcopy="${command_line}"
}

typeset -g _fzf_dir_preview='if command -v eza > /dev/null 2>&1; then eza --tree --level=2 --color=always --icons=auto -- {}; else ls -la -- {}; fi | head -n 200'

typeset -gA _fzf_menu=()
typeset -g _fzf_git_log_format='%H%x09%C(auto)%h%d %s %C(black)%C(bold)%cr'
