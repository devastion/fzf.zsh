# shellcheck shell=sh disable=SC2296

Describe 'fzf helpers'
  BeforeEach 'load_plugin'

  Describe '_fzf_func_description'
    write_func() { printf '#!/usr/bin/env zsh\n%s\n' "$1" > "${SHELLSPEC_TMPBASE}/func"; }

    It 'extracts the "# desc:" line'
      write_func '# desc: Do a thing'
      When call _fzf_func_description "${SHELLSPEC_TMPBASE}/func"
      The status should be success
      The value "${REPLY}" should eq 'Do a thing'
    End

    It 'fails when there is no description'
      write_func 'foo() { :; }'
      When call _fzf_func_description "${SHELLSPEC_TMPBASE}/func"
      The status should be failure
      The value "${REPLY}" should eq ''
    End
  End

  Describe '_fzf_listener_pids'
    It 'collects every pid from ss/lsof style output'
      When call _fzf_listener_pids 'users:(("a",pid=12,fd=3),("b",pid=345,fd=4))'
      The value "${(j:,:)reply}" should eq '12,345'
    End

    It 'returns an empty list without a match'
      When call _fzf_listener_pids 'nothing here'
      The value "${#reply}" should eq 0
    End
  End

  Describe '_fzf_require_git_work_tree'
    It 'fails outside a git work tree'
      outside() { cd "${SHELLSPEC_TMPBASE}" && GIT_CEILING_DIRECTORIES="${SHELLSPEC_TMPBASE}" _fzf_require_git_work_tree; }
      When call outside
      The status should be failure
      The stderr should eq 'Not a git repository'
    End

    It 'succeeds inside a git work tree'
      inside() {
        mkdir -p "${SHELLSPEC_TMPBASE}/repo" && cd "${SHELLSPEC_TMPBASE}/repo" &&
          git init -q && _fzf_require_git_work_tree
      }
      When call inside
      The status should be success
    End
  End

  Describe '_fzf_list_paths (find fallback)'
    list() {
      mkdir -p "${SHELLSPEC_TMPBASE}/tree/sub" "${SHELLSPEC_TMPBASE}/tree/.git"
      : > "${SHELLSPEC_TMPBASE}/tree/sub/file"
      : > "${SHELLSPEC_TMPBASE}/tree/.git/ignored"
      cd "${SHELLSPEC_TMPBASE}/tree" || return
      PATH=/usr/bin:/bin
      rehash
      _fzf_list_paths "$1" | tr '\0' '\n'
    }

    It 'lists files and skips .git'
      When call list f
      The output should eq './sub/file'
    End

    It 'lists directories and skips .git'
      When call list d
      The output should eq './sub'
    End
  End
End
