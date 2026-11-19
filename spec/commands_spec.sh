# shellcheck shell=sh disable=SC2296,SC2154

Describe 'fzf commands'
  BeforeEach 'load_plugin' 'stub_fzf'
  Before '_fzf_dir="${SHELLSPEC_PROJECT_ROOT}"; _fzf_dir_preview=preview'

  Describe 'fcd'
    It 'changes into the selected directory'
      go() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work/sub"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        FZF_OUTPUT="./sub$(printf '\0')" fcd && print -r -- "${PWD:t}"
      }
      When call go
      The output should eq sub
    End

    It 'stays put when nothing is selected'
      stay() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        unset FZF_OUTPUT
        fcd
        print -r -- "$?|${PWD:t}"
      }
      When call stay
      The output should eq '1|work'
    End

    It 'passes the query to fzf'
      query() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        unset FZF_OUTPUT
        fcd foo bar
        cat "${FZF_ARGS_FILE}"
      }
      When call query
      The output should include '--query=foo bar'
    End
  End

  Describe 'fk'
    It 'rejects unknown options'
      When call fk -x
      The status should eq 2
      The stderr should be present
    End

    It 'signals the selected pids with the chosen signal'
      sig() {
        sleep 30 &
        local pid=$!
        FZF_OUTPUT="  ${pid} user 0.0 0.0 sleep 30" fk -s KILL
        local rc=$?
        wait "${pid}" 2> /dev/null
        print -r -- "${rc}|$?"
      }
      When call sig
      The output should eq '0|137'
    End

    It 'fails when nothing is selected'
      When call fk
      The status should be failure
    End
  End

  Describe 'fmenu'
    It 'fails when no selector functions exist'
      empty() {
        _fzf_dir="${SHELLSPEC_TMPBASE}/empty"
        mkdir -p "${_fzf_dir}/functions"
        _fzf_menu=()
        fmenu
      }
      When call empty
      The status should eq 1
      The stderr should eq 'fmenu: no selector functions found'
    End

    It 'runs the selected function'
      run() {
        _fzf_dir="${SHELLSPEC_TMPBASE}/menu"
        mkdir -p "${_fzf_dir}/functions"
        printf '#!/usr/bin/env zsh\n# desc: Say hi\n' > "${_fzf_dir}/functions/sayhi"
        sayhi() { print -r -- hi-from-sayhi; }
        _fzf_menu=()
        FZF_OUTPUT='sayhi	Say hi	body' fmenu
      }
      When call run
      The output should eq hi-from-sayhi
    End

    It 'lists each selector with its description'
      list() {
        _fzf_dir="${SHELLSPEC_TMPBASE}/menu"
        mkdir -p "${_fzf_dir}/functions"
        printf '#!/usr/bin/env zsh\n# desc: Say hi\n' > "${_fzf_dir}/functions/sayhi"
        sayhi() { :; }
        _fzf_menu=()
        unset FZF_OUTPUT
        fmenu > /dev/null
        cat "${FZF_INPUT_FILE}"
      }
      When call list
      The output should include 'sayhi'
      The output should include 'Say hi'
    End
  End

  Describe 'fh'
    It 'prints a multi-line history entry whole'
      hist() {
        :
        FZF_OUTPUT=$'echo one\necho two' fh -p
      }
      When call hist
      The output should eq "echo one
echo two"
    End

    It 'offers newest entries first, NUL separated'
      order() {
        # the last line read stands in for the running command and is dropped
        printf 'first\nsecond\ncurrent\n' > "${SHELLSPEC_TMPBASE}/hist"
        fc -R "${SHELLSPEC_TMPBASE}/hist"
        unset FZF_OUTPUT
        fh > /dev/null
        tr '\0' '|' < "${FZF_INPUT_FILE}"
      }
      When call order
      The output should eq 'second|first|'
    End
  End

  Describe 'fdef'
    It 'prints the selected alias'
      pick() { alias fdef_demo='echo hi'; FZF_OUTPUT='fdef_demo	alias	x' fdef; }
      When call pick
      The output should include "fdef_demo='echo hi'"
    End

    It 'removes its temporary files'
      clean() {
        local tmp="${SHELLSPEC_TMPBASE}/tmp"
        mkdir -p "${tmp}"
        unset FZF_OUTPUT
        TMPDIR="${tmp}" fdef > /dev/null
        print -r -- "$(ls "${tmp}" | wc -l | tr -d ' ')"
      }
      When call clean
      The output should eq 0
    End
  End

  Describe 'frg'
    It 'does not search for an empty query'
      args() { fake_cmd rg 'exit 0'; unset FZF_OUTPUT; frg; cat "${FZF_ARGS_FILE}"; }
      When call args
      The output should include 'test -z {q} ||'
    End
  End

  Describe 'fssh'
    It 'lists literal hosts, following Include and skipping patterns'
      hosts() {
        local home="${SHELLSPEC_TMPBASE}/home"
        mkdir -p "${home}/.ssh/conf.d"
        printf 'Host alpha beta\nHost *.example.com\nInclude conf.d/*\n' > "${home}/.ssh/config"
        printf 'Host gamma\n' > "${home}/.ssh/conf.d/extra"
        unset FZF_OUTPUT
        HOME="${home}" fssh > /dev/null
        cat "${FZF_INPUT_FILE}"
      }
      When call hosts
      The line 1 of output should eq alpha
      The line 2 of output should eq beta
      The line 3 of output should eq gamma
      The lines of output should eq 3
    End
  End

  Describe '_fzf_function_file'
    It 'writes the body of a loaded function to the target'
      body() { _fzf_function_file demo "${SHELLSPEC_TMPBASE}/out" && cat "${REPLY}"; }
      demo() { echo demo-body; }
      When call body
      The output should include 'demo-body'
    End

    It 'resolves an autoload stub to its file on fpath'
      stubbed() {
        local d="${SHELLSPEC_TMPBASE}/fp"
        mkdir -p "${d}"
        print -r -- 'lazy() { echo lazy-body; }' > "${d}/lazy"
        fpath=("${d}" $fpath)
        autoload -Uz lazy
        _fzf_function_file lazy "${SHELLSPEC_TMPBASE}/unused" && print -r -- "${REPLY}"
      }
      When call stubbed
      The output should eq "${SHELLSPEC_TMPBASE}/fp/lazy"
    End

    It 'fails for an unknown function'
      When call _fzf_function_file no_such_function_xyz "${SHELLSPEC_TMPBASE}/out"
      The status should be failure
    End
  End
End
