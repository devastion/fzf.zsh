# shellcheck shell=sh disable=SC2296,SC2154

# Run the commands against the real fzf in --filter mode, which needs no
# terminal. This catches flags that fzf rejects; the preview and bind strings
# are not run in this mode.
no_fzf() { ! command -v fzf > /dev/null 2>&1; }

Describe 'real fzf'
  Skip if 'fzf is not installed' no_fzf
  BeforeEach 'load_plugin' 'plugin_env'
  Before 'unset FZF_DEFAULT_OPTS_FILE FZF_DEFAULT_COMMAND; export FZF_DEFAULT_OPTS=--filter=wanted'

  It 'fcd changes into the matching directory'
    go() {
      mkdir -p "${SHELLSPEC_TMPBASE}/real/wanted" "${SHELLSPEC_TMPBASE}/real/other"
      cd "${SHELLSPEC_TMPBASE}/real" || return
      fcd && print -r -- "${PWD:t}"
    }
    When call go
    The output should eq wanted
  End

  It 'ff prints the matching file'
    pick() {
      mkdir -p "${SHELLSPEC_TMPBASE}/real"
      : > "${SHELLSPEC_TMPBASE}/real/wanted.txt"
      : > "${SHELLSPEC_TMPBASE}/real/other.txt"
      cd "${SHELLSPEC_TMPBASE}/real" || return
      ff
    }
    When call pick
    The output should end with 'wanted.txt'
  End

  It 'fenv prints the matching variable'
    pick() { export wanted_var=value; fenv; }
    When call pick
    The output should eq value
  End

  It 'fgsw switches to the matching branch'
    sw() {
      git_repo
      git branch wanted
      git branch other
      fgsw > /dev/null 2>&1
      git branch --show-current
    }
    When call sw
    The output should eq wanted
  End

  It 'fgdel deletes the matching branch'
    del() {
      git_repo
      git branch wanted
      git branch other
      fgdel > /dev/null
      git branch --format='%(refname:short)' | tr '\n' ','
    }
    When call del
    The output should eq 'main,other,'
  End

  It 'fdef prints the matching alias'
    pick() { alias wanted_alias='echo hi'; fdef; }
    When call pick
    The output should include "wanted_alias='echo hi'"
  End

  It 'fgl accepts its options'
    log() {
      git_repo
      git commit -q --allow-empty -m wanted
      fgl
    }
    When call log
    The output should include 'wanted'
  End
End
