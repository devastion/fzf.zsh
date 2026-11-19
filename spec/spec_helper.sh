# shellcheck shell=sh disable=SC2296,SC2066
# Loaded by ShellSpec (running under zsh). Plugin code is zsh-only, so it is
# loaded from inside a function that switches to zsh emulation.

load_plugin() {
  emulate -L zsh
  fpath=("${SHELLSPEC_PROJECT_ROOT}/functions" $fpath)
  autoload -Uz -- "${SHELLSPEC_PROJECT_ROOT}"/functions/*(:t)
}

spec_helper_precheck() {
  load_plugin
}

# Put a fake `fzf` first on PATH. It records its arguments in $FZF_ARGS_FILE
# (one per line) and $FZF_ARGS_FILE.0 (NUL separated), saves stdin to
# $FZF_INPUT_FILE and prints $FZF_OUTPUT (or fails if unset). When
# $FZF_SEQ_DIR is set, each call prints and removes the next file in it, and
# fails once it is empty (see fzf_seq). When $FZF_PICK is set, it prints the
# first input line matching that grep pattern.
stub_fzf() {
  rm -rf "${SHELLSPEC_TMPBASE}/fzfbin"
  mkdir -p "${SHELLSPEC_TMPBASE}/fzfbin"
  FZF_ARGS_FILE="${SHELLSPEC_TMPBASE}/fzf.args"
  FZF_INPUT_FILE="${SHELLSPEC_TMPBASE}/fzf.input"
  export FZF_ARGS_FILE FZF_INPUT_FILE
  cat > "${SHELLSPEC_TMPBASE}/fzfbin/fzf" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "$FZF_ARGS_FILE"
printf '%s\0' "$@" > "$FZF_ARGS_FILE.0"
cat > "$FZF_INPUT_FILE"
if [ -n "${FZF_PICK-}" ]; then
  grep -m 1 -e "$FZF_PICK" "$FZF_INPUT_FILE"
  exit
fi
if [ -n "${FZF_SEQ_DIR-}" ]; then
  next=$(ls "$FZF_SEQ_DIR" | sort | head -n 1)
  [ -n "$next" ] || exit 130
  cat "$FZF_SEQ_DIR/$next"
  rm "$FZF_SEQ_DIR/$next"
  exit 0
fi
[ -n "${FZF_OUTPUT+x}" ] || exit 130
printf '%s' "$FZF_OUTPUT"
STUB
  chmod +x "${SHELLSPEC_TMPBASE}/fzfbin/fzf"
  PATH="${SHELLSPEC_TMPBASE}/fzfbin:${PATH}"
  rehash
}

# Variables the plugin file normally sets.
plugin_env() {
  _fzf_dir="${SHELLSPEC_PROJECT_ROOT}"
  _fzf_dir_preview=preview
  _fzf_clipcopy="cat > ${SHELLSPEC_TMPBASE}/clip"
  _fzf_git_log_format='%H%x09%h %s'
}

# Put a fake command first on PATH. $1 is the name, $2 the sh body.
fake_cmd() {
  mkdir -p "${SHELLSPEC_TMPBASE}/fzfbin"
  printf '#!/bin/sh\n%s\n' "$2" > "${SHELLSPEC_TMPBASE}/fzfbin/$1"
  chmod +x "${SHELLSPEC_TMPBASE}/fzfbin/$1"
  rehash
}

# Create a fresh git repository with one commit and make it the cwd.
git_repo() {
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  rm -rf "${SHELLSPEC_TMPBASE}/repo"
  mkdir -p "${SHELLSPEC_TMPBASE}/repo"
  cd "${SHELLSPEC_TMPBASE}/repo" || return
  git init -q
  git symbolic-ref HEAD refs/heads/main
  git commit -q --allow-empty -m init
}

# Make successive fzf calls print the given outputs, then fail (cancel).
fzf_seq() {
  emulate -L zsh
  local i=0 out
  export FZF_SEQ_DIR="${SHELLSPEC_TMPBASE}/fzfseq"
  rm -rf "${FZF_SEQ_DIR}"
  mkdir -p "${FZF_SEQ_DIR}"
  for out in "$@"; do
    printf '%s' "${out}" > "${FZF_SEQ_DIR}/$((i += 1))"
  done
}

# Run the --preview command the last fzf call received, with every {}, {1},
# {2} and {3} replaced by the quoted argument $1.
run_preview() {
  emulate -L zsh
  local -a args=("${(@0)$(< "${FZF_ARGS_FILE}.0")}")
  local cmd='' arg placeholder
  for arg in "${(@)args}"; do
    [[ "${arg}" == --preview=* ]] && cmd="${arg#--preview=}"
  done
  if [[ -z "${cmd}" ]]; then
    local i
    for i in {1..${#args}}; do
      [[ "${args[i]}" == --preview ]] && cmd="${args[i+1]}"
    done
  fi
  [[ -n "${cmd}" ]] || { print -u2 -r -- 'no --preview given'; return 1; }
  for placeholder in '{}' '{1}' '{2}' '{3}'; do
    cmd="${cmd//${placeholder}/${(qq)1}}"
  done
  # fzf ignores the exit status of a preview, so do the same.
  FZF_PREVIEW_COLUMNS=80 sh -c "${cmd}" || true
}

# --- Driving the real fzf UI through tmux (see spec/ui_spec.sh) ---

no_ui_tools() {
  ! command -v tmux > /dev/null 2>&1 || ! command -v fzf > /dev/null 2>&1
}

# Run zsh code with the plugin functions loaded inside a detached tmux pane.
# $1 is the working directory, $2 the code to run.
ui_start() {
  local script="${SHELLSPEC_TMPBASE}/ui.zsh"
  {
    print -r -- "fpath=(${(q)SHELLSPEC_PROJECT_ROOT}/functions \$fpath)"
    print -r -- "autoload -Uz -- ${(q)SHELLSPEC_PROJECT_ROOT}/functions/*(:t)"
    print -r -- "_fzf_dir=${(q)SHELLSPEC_PROJECT_ROOT}"
    print -r -- "_fzf_dir_preview='ls -la -- {}'"
    print -r -- "_fzf_clipcopy='cat > ${SHELLSPEC_TMPBASE}/clip'"
    print -r -- "_fzf_git_log_format='%H%x09%h %s'"
    # The plugin must not depend on the login shell understanding its commands.
    print -r -- "export SHELL=/bin/false"
    print -r -- "$2"
  } > "${script}"
  rm -f "${SHELLSPEC_TMPBASE}/clip"
  tmux -L fzfspec kill-server 2> /dev/null
  env -u FZF_DEFAULT_OPTS -u FZF_DEFAULT_OPTS_FILE -u FZF_DEFAULT_COMMAND \
    tmux -L fzfspec -f /dev/null new-session -d -x 140 -y 40 -c "$1" \
    "zsh -f ${(q)script}; sleep 30"
}

ui_stop() {
  tmux -L fzfspec kill-server 2> /dev/null
  return 0
}

ui_keys() {
  tmux -L fzfspec send-keys "$@"
}

# Wait for a shell condition, 10 seconds by default (UI_WAIT is in tenths of
# a second); dump the pane when it fails.
ui_until() {
  local i
  for i in {1..${UI_WAIT:-100}}; do
    eval "$1" && return 0
    sleep 0.1
  done
  print -u2 -r -- "timed out waiting for: $1"
  tmux -L fzfspec capture-pane -p 2> /dev/null >&2
  return 1
}

ui_screen_has() {
  tmux -L fzfspec capture-pane -p 2> /dev/null | grep -qF -- "$1"
}
