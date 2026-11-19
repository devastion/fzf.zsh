# shellcheck shell=sh disable=SC2296,SC2154,SC2016

# These specs drive the real fzf inside tmux, so previews and key bindings run
# for real. They skip themselves without tmux or fzf.
Describe 'fzf UI'
  Skip if 'tmux or fzf is missing' no_ui_tools
  BeforeEach 'load_plugin' 'rm -rf "${SHELLSPEC_TMPBASE}/fzfbin"'
  AfterEach 'ui_stop'

  It 'fgl previews a commit and ctrl-y copies its hash'
    run() {
      git_repo
      ui_start "${PWD}" 'fgl'
      ui_until 'ui_screen_has Author:' || return 1
      ui_keys C-y
      ui_until '[[ -s "${SHELLSPEC_TMPBASE}/clip" ]]' || return 1
      [[ "$(< "${SHELLSPEC_TMPBASE}/clip")" == "$(git rev-parse HEAD)" ]] && print ok
    }
    When call run
    The output should eq ok
  End

  It 'fenv previews a value and ctrl-y copies it'
    run() {
      export UI_SPEC_VAR=hello-ui
      ui_start "${SHELLSPEC_TMPBASE}" 'fenv'
      ui_until 'ui_screen_has "enter print value"' || return 1
      ui_keys UI_SPEC_VAR
      ui_until 'ui_screen_has hello-ui' || return 1
      ui_keys C-y
      ui_until '[[ -s "${SHELLSPEC_TMPBASE}/clip" ]]' || return 1
      print -r -- "$(< "${SHELLSPEC_TMPBASE}/clip")"
    }
    When call run
    The output should eq hello-ui
  End

  It 'fga previews the diff and stages the tab-selected file'
    run() {
      git_repo
      echo ui-preview > a.txt
      ui_start "${PWD}" 'fga'
      ui_until 'ui_screen_has ui-preview' || return 1
      ui_keys Tab Enter
      ui_until '[[ "$(git diff --cached --name-only)" == a.txt ]]' || return 1
      print ok
    }
    When call run
    The output should eq ok
  End

  It 'fgsw previews a branch and switches to the typed one'
    run() {
      git_repo
      git branch feat
      ui_start "${PWD}" 'fgsw'
      ui_until 'ui_screen_has init' || return 1
      ui_keys feat Enter
      ui_until '[[ "$(git branch --show-current)" == feat ]]' || return 1
      print ok
    }
    When call run
    The output should eq ok
  End

  Describe 'fgst'
    stash_repo() {
      git_repo
      echo a > f
      git add f
      git commit -q -m add
      echo b > f
      git stash -q
    }

    It 'pops the stash with ctrl-p'
      run() {
        stash_repo
        ui_start "${PWD}" 'fgst'
        ui_until 'ui_screen_has "WIP on main"' || return 1
        ui_keys C-p
        ui_until '[[ -z "$(git stash list 2> /dev/null)" ]]' || return 1
        print ok
      }
      When call run
      The output should eq ok
    End

    It 'drops the stash with the delete key'
      run() {
        stash_repo
        ui_start "${PWD}" 'fgst'
        ui_until 'ui_screen_has "WIP on main"' || return 1
        ui_keys DC
        ui_until '[[ -z "$(git stash list 2> /dev/null)" ]]' || return 1
        [[ "$(< f)" == a ]] && print ok
      }
      When call run
      The output should eq ok
    End
  End

  Describe 'frg'
    no_rg() { ! command -v rg > /dev/null 2>&1; }
    Skip if 'rg is missing' no_rg

    It 'searches as you type and opens the match at its line'
      run() {
        git_repo
        printf 'one\nneedle here\n' > a.txt
        printf '#!/bin/sh\necho "$*" > "%s/editor"\n' "${SHELLSPEC_TMPBASE}" > "${SHELLSPEC_TMPBASE}/ed"
        chmod +x "${SHELLSPEC_TMPBASE}/ed"
        rm -f "${SHELLSPEC_TMPBASE}/editor"
        ui_start "${PWD}" "export EDITOR=${(q)SHELLSPEC_TMPBASE}/ed; frg"
        ui_until 'ui_screen_has enter\ open' || return 1
        ui_keys needle
        ui_until 'ui_screen_has "needle here"' || return 1
        ui_keys Enter
        ui_until '[[ -s "${SHELLSPEC_TMPBASE}/editor" ]]' || return 1
        print -r -- "$(< "${SHELLSPEC_TMPBASE}/editor")"
      }
      When call run
      The output should match pattern '+2 -- *a.txt'
    End
  End

  It 'fgfix previews a commit and commits a fixup of it'
    run() {
      git_repo
      echo x > a.txt
      git add a.txt
      ui_start "${PWD}" 'fgfix'
      ui_until 'ui_screen_has Author:' || return 1
      ui_keys Enter
      ui_until '[[ "$(git log -1 --format=%s)" == "fixup! init" ]]' || return 1
      print ok
    }
    When call run
    The output should eq ok
  End

  It 'fk signals the process picked by query'
    run() {
      sleep 4242 &
      local pid=$!
      ui_start "${SHELLSPEC_TMPBASE}" 'fk -s KILL'
      ui_until 'ui_screen_has "enter send SIGKILL"' || return 1
      ui_keys 'sleep 4242'
      ui_until 'ui_screen_has "sleep 4242"' || return 1
      ui_keys Enter
      ui_until '! kill -0 "${pid}" 2> /dev/null || [[ "$(ps -o stat= -p "${pid}")" == Z* ]]' || return 1
      wait "${pid}" 2> /dev/null
      print "ok|$?"
    }
    When call run
    The output should eq 'ok|137'
  End

  It 'ftail previews a log and follows it'
    run() {
      mkdir -p "${SHELLSPEC_TMPBASE}/uilogs"
      echo tail-ui-line > "${SHELLSPEC_TMPBASE}/uilogs/a.log"
      ui_start "${SHELLSPEC_TMPBASE}" "ftail ${(q)SHELLSPEC_TMPBASE}/uilogs"
      ui_until 'ui_screen_has tail-ui-line' || return 1
      ui_keys Enter
      sleep 0.5
      echo appended-live >> "${SHELLSPEC_TMPBASE}/uilogs/a.log"
      ui_until 'ui_screen_has appended-live' || return 1
      ui_keys C-c
      print ok
    }
    When call run
    The output should eq ok
  End

  It 'fman previews a page and opens it'
    run() {
      fake_cmd man 'if [ "$1" = -k ]; then echo "foo(1) - demo"; else echo "man $*"; fi'
      PATH="${SHELLSPEC_TMPBASE}/fzfbin:${PATH}"
      ui_start "${SHELLSPEC_TMPBASE}" 'fman'
      ui_until 'ui_screen_has "man 1 foo"' || return 1
      ui_keys Enter
      sleep 0.5
      ui_until 'ui_screen_has "man 1 foo"' || return 1
      print ok
    }
    When call run
    The output should eq ok
  End

  It 'fssh previews a host and connects to it'
    run() {
      local home="${SHELLSPEC_TMPBASE}/uihome"
      mkdir -p "${home}/.ssh"
      printf 'Host alpha\n' > "${home}/.ssh/config"
      rm -f "${SHELLSPEC_TMPBASE}/ssh.args"
      fake_cmd ssh "if [ \"\$1\" = -G ]; then echo 'hostname ui.example.org'; else echo \"\$*\" > ${SHELLSPEC_TMPBASE}/ssh.args; fi"
      PATH="${SHELLSPEC_TMPBASE}/fzfbin:${PATH}"
      export HOME="${home}"
      ui_start "${SHELLSPEC_TMPBASE}" 'fssh'
      ui_until 'ui_screen_has ui.example.org' || return 1
      ui_keys Enter
      ui_until '[[ -s "${SHELLSPEC_TMPBASE}/ssh.args" ]]' || return 1
      print -r -- "$(< "${SHELLSPEC_TMPBASE}/ssh.args")"
    }
    When call run
    The output should eq '-- alpha'
  End
End
