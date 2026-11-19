# shellcheck shell=sh disable=SC2296,SC2154,SC2034

Describe 'fzf misc commands'
  BeforeEach 'load_plugin' 'stub_fzf' 'plugin_env'

  Describe '_fzf'
    It 'runs fzf with sh as $SHELL'
      shell() {
        fake_cmd fzf 'cat > /dev/null; echo "$SHELL" > "$FZF_ARGS_FILE"; exit 130'
        SHELL=/bin/zsh fp
        cat "${FZF_ARGS_FILE}"
      }
      When call shell
      The output should eq /bin/sh
    End
  End

  Describe 'ff'
    It 'rejects unknown options'
      When call ff -x
      The status should eq 2
      The stderr should be present
    End

    It 'prints the selected path'
      pick() { FZF_OUTPUT=a.txt ff; }
      When call pick
      The output should eq a.txt
    End

    It 'separates paths with NUL under --print0'
      pick() { FZF_OUTPUT=a.txt ff --print0 | tr '\0' '|'; }
      When call pick
      The output should eq 'a.txt|'
    End

    It 'fails when nothing is selected'
      none() { unset FZF_OUTPUT; ff; }
      When call none
      The status should eq 1
    End
  End

  Describe 'fe'
    It 'opens the selection in $EDITOR'
      edit() { FZF_OUTPUT=a.txt EDITOR=echo fe; }
      When call edit
      The output should eq '-- a.txt'
    End

    It 'fails when nothing is selected'
      none() { unset FZF_OUTPUT; EDITOR=echo fe; }
      When call none
      The status should eq 1
    End
  End

  Describe 'fenv'
    It 'prints the value of the selected variable'
      pick() { export FZF_SPEC_VAR=hello; FZF_OUTPUT=FZF_SPEC_VAR fenv; }
      When call pick
      The output should eq hello
    End

    It 'offers exported variables only'
      offer() {
        export FZF_SPEC_EXPORTED=1
        FZF_SPEC_PLAIN=1
        unset FZF_OUTPUT
        fenv
        grep -cx -e FZF_SPEC_EXPORTED -e FZF_SPEC_PLAIN "${FZF_INPUT_FILE}"
      }
      When call offer
      The output should eq 1
    End
  End

  Describe 'fp'
    It 'changes to the selected PATH entry'
      go() {
        mkdir -p "${SHELLSPEC_TMPBASE}/bin1"
        FZF_OUTPUT="${SHELLSPEC_TMPBASE}/bin1" fp && print -r -- "${PWD:t}"
      }
      When call go
      The output should eq bin1
    End
  End

  Describe 'fcrecent'
    It 'changes to a directory from the stack'
      go() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work/sub"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        pushd -q sub
        PATH="${SHELLSPEC_TMPBASE}/fzfbin:/usr/bin:/bin"
        rehash
        FZF_OUTPUT="${SHELLSPEC_TMPBASE}/work" fcrecent && print -r -- "${PWD:t}"
      }
      When call go
      The output should eq work
    End

    It 'fails without recent directories'
      none() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        dirstack=()
        PATH="${SHELLSPEC_TMPBASE}/fzfbin:/usr/bin:/bin"
        rehash
        fcrecent
      }
      When call none
      The status should eq 1
      The stderr should eq 'fcrecent: no recent directories'
    End
  End

  Describe 'fkp'
    It 'fails when the listing tool is missing'
      missing() { PATH=/nonexistent; rehash; fkp; }
      When call missing
      The status should eq 127
      The stderr should include 'not found'
    End

    Parameters
      darwin
      linux-gnu
    End

    It "terminates the selected listener on $1"
      term() {
        OSTYPE="$1"
        sleep 30 &
        local pid=$! line
        if [[ "${OSTYPE}" == darwin* ]]; then
          fake_cmd lsof 'echo HEADER'
          line="node ${pid} user"
        else
          fake_cmd ss 'echo HEADER'
          line="users:((\"node\",pid=${pid},fd=3))"
        fi
        FZF_OUTPUT="${line}" fkp > /dev/null
        local rc=$?
        wait "${pid}" 2> /dev/null
        print -r -- "${rc}|$?"
      }
      When call term "$1"
      The output should eq '0|143'
    End
  End

  Describe 'fssh (config parsing)'
    config() {
      local home="${SHELLSPEC_TMPBASE}/home"
      rm -rf "${home}"
      mkdir -p "${home}/.ssh"
      HOME="${home}"
    }

    It 'handles quoted names, absolute includes and include loops'
      parse() {
        config
        printf 'Host "quoted one"\nInclude %s/abs.conf\nInclude config\n' "${HOME}/.ssh" > "${HOME}/.ssh/config"
        printf 'host Upper\n' > "${HOME}/.ssh/abs.conf"
        unset FZF_OUTPUT
        fssh > /dev/null
        tr '\n' ',' < "${FZF_INPUT_FILE}"
      }
      When call parse
      The output should eq 'Upper,quoted one,'
    End

    It 'connects to the selected host'
      connect() {
        config
        printf 'Host alpha\n' > "${HOME}/.ssh/config"
        fake_cmd ssh 'echo "ssh $*"'
        FZF_OUTPUT=alpha fssh
      }
      When call connect
      The output should eq 'ssh -- alpha'
    End

    It 'fails without a literal host'
      none() {
        config
        printf 'Host *\n' > "${HOME}/.ssh/config"
        fssh
      }
      When call none
      The status should eq 1
      The stderr should include 'no literal hosts'
    End
  End

  Describe 'fcd (listing)'
    It 'offers the directories below the current one'
      list() {
        mkdir -p "${SHELLSPEC_TMPBASE}/work/sub"
        : > "${SHELLSPEC_TMPBASE}/work/file"
        cd "${SHELLSPEC_TMPBASE}/work" || return
        unset FZF_OUTPUT
        fcd
        tr '\0' '\n' < "${FZF_INPUT_FILE}"
      }
      When call list
      The output should include 'sub'
      The output should not include 'file'
    End
  End

  Describe 'fdef preview'
    It 'shows the definition file of the highlighted entry'
      preview() {
        alias fdef_prev='echo prev-body'
        unset FZF_OUTPUT
        fdef > /dev/null
        printf 'prev-body\n' > "${SHELLSPEC_TMPBASE}/prevfile"
        run_preview "${SHELLSPEC_TMPBASE}/prevfile"
      }
      When call preview
      The output should include 'prev-body'
    End
  End

  Describe 'previews'
    It 'fman renders the highlighted page'
      preview() {
        fake_cmd man 'echo "man $*"'
        unset FZF_OUTPUT
        fman > /dev/null
        run_preview 'foo(1) - demo'
      }
      When call preview
      The output should eq 'man 1 foo'
    End

    It 'fssh shows the resolved settings of the highlighted host'
      preview() {
        local home="${SHELLSPEC_TMPBASE}/home"
        mkdir -p "${home}/.ssh"
        printf 'Host alpha\n' > "${home}/.ssh/config"
        fake_cmd ssh 'printf "hostname example.org\nuser bob\nnoise 1\n"'
        unset FZF_OUTPUT
        HOME="${home}" fssh > /dev/null
        run_preview alpha
      }
      When call preview
      The line 1 of output should eq 'hostname example.org'
      The line 2 of output should eq 'user bob'
      The lines of output should eq 2
    End

    It 'fk shows the highlighted process line'
      preview() { unset FZF_OUTPUT; fk > /dev/null; run_preview '  42 user 0.0 0.0 sleep 30'; }
      When call preview
      The output should eq '  42 user 0.0 0.0 sleep 30'
    End

    It 'fenv shows the value of the highlighted variable'
      preview() { export FZF_SPEC_PREV=shown; unset FZF_OUTPUT; fenv > /dev/null; run_preview FZF_SPEC_PREV; }
      When call preview
      The output should eq shown
    End

    It 'ftail shows the end of the highlighted file'
      preview() {
        mkdir -p "${SHELLSPEC_TMPBASE}/logs"
        printf 'line one\nline two\n' > "${SHELLSPEC_TMPBASE}/logs/a.log"
        unset FZF_OUTPUT
        ftail "${SHELLSPEC_TMPBASE}/logs" > /dev/null
        run_preview "${SHELLSPEC_TMPBASE}/logs/a.log"
      }
      When call preview
      The output should eq 'line one
line two'
    End
  End

  Describe 'fkp (real listing tool)'
    no_listener_tools() {
      local tool=ss
      [[ "${OSTYPE}" == darwin* ]] && tool=lsof
      ! command -v python3 > /dev/null 2>&1 || ! command -v "${tool}" > /dev/null 2>&1
    }
    Skip if 'python3 or lsof/ss is missing' no_listener_tools

    It 'terminates a real listening process'
      real() {
        local portfile="${SHELLSPEC_TMPBASE}/port" port rc
        : > "${portfile}"
        python3 -c 'import socket,time
s=socket.socket()
s.bind(("127.0.0.1",0))
s.listen()
print(s.getsockname()[1],flush=True)
time.sleep(60)' > "${portfile}" &
        local pid=$!
        until [[ -s "${portfile}" ]]; do sleep 0.1; done
        port="$(< "${portfile}")"
        FZF_PICK=":${port}" fkp > /dev/null
        rc=$?
        wait "${pid}" 2> /dev/null
        print -r -- "${rc}|$?"
      }
      When call real
      The output should eq '0|143'
    End
  End

  Describe 'fman'
    It 'opens the selected manual page'
      fake_man() { fake_cmd man 'if [ "$1" = -k ]; then echo "foo(1) - demo"; else echo "man $*"; fi'; }
      BeforeCall 'fake_man'
      pick() { FZF_OUTPUT='foo(1) - demo' fman; }
      When call pick
      The output should eq 'man 1 foo'
    End
  End

  Describe 'ftail'
    It 'follows the selected log file'
      follow() {
        fake_cmd tail 'echo "tail $*"'
        mkdir -p "${SHELLSPEC_TMPBASE}/logs"
        : > "${SHELLSPEC_TMPBASE}/logs/a.log"
        FZF_OUTPUT="${SHELLSPEC_TMPBASE}/logs/a.log" ftail "${SHELLSPEC_TMPBASE}/logs"
      }
      When call follow
      The output should eq "tail -f -- ${SHELLSPEC_TMPBASE}/logs/a.log"
    End

    It 'lists the log files below the given directory'
      list() {
        mkdir -p "${SHELLSPEC_TMPBASE}/logs"
        : > "${SHELLSPEC_TMPBASE}/logs/a.log"
        : > "${SHELLSPEC_TMPBASE}/logs/skip.txt"
        unset FZF_OUTPUT
        ftail "${SHELLSPEC_TMPBASE}/logs"
        cat "${FZF_INPUT_FILE}"
      }
      When call list
      The output should include 'a.log'
      The output should not include 'skip.txt'
    End
  End
End
