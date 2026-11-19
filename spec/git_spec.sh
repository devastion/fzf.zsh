# shellcheck shell=sh disable=SC2296,SC2154

Describe 'fzf git commands'
  BeforeEach 'load_plugin' 'stub_fzf' 'plugin_env'

  Describe 'outside a repository'
    It 'fga refuses to run'
      outside() { cd "${SHELLSPEC_TMPBASE}" && GIT_CEILING_DIRECTORIES="${SHELLSPEC_TMPBASE}" fga; }
      When call outside
      The status should be failure
      The stderr should eq 'Not a git repository'
    End
  End

  Describe 'fga'
    It 'stages the selected file only'
      stage() {
        git_repo
        echo x > a.txt
        echo y > b.txt
        FZF_OUTPUT=a.txt fga
        git diff --cached --name-only
      }
      When call stage
      The output should eq a.txt
    End

    It 'offers untracked and modified paths'
      offer() {
        git_repo
        echo x > a.txt
        unset FZF_OUTPUT
        fga
        tr '\0' '\n' < "${FZF_INPUT_FILE}"
      }
      When call offer
      The output should eq a.txt
    End

    It 'offers a renamed file once, under its new name'
      renamed() {
        git_repo
        echo x > old.txt
        git add old.txt
        git commit -q -m old
        git mv old.txt new.txt
        unset FZF_OUTPUT
        fga
        tr '\0' '\n' < "${FZF_INPUT_FILE}"
      }
      When call renamed
      The output should eq new.txt
    End

    It 'previews the diff of the selected file'
      preview() {
        git_repo
        echo hello-preview > a.txt
        unset FZF_OUTPUT
        fga
        run_preview a.txt
      }
      When call preview
      The output should include 'hello-preview'
    End

    It 'reports when there is nothing to stage'
      empty() { git_repo; fga; }
      When call empty
      The status should eq 1
      The stderr should eq 'fga: nothing to stage'
    End
  End

  Describe 'fgalias'
    It 'lists the configured aliases'
      list() {
        git_repo
        git config alias.co checkout
        unset FZF_OUTPUT
        fgalias
        cat "${FZF_INPUT_FILE}"
      }
      When call list
      The output should include 'co'
      The output should include 'checkout'
    End
  End

  Describe 'fgdel'
    It 'rejects unknown options'
      When call fgdel -x
      The status should eq 2
      The stderr should be present
    End

    It 'does not offer the current branch'
      offer() {
        git_repo
        git branch feat
        unset FZF_OUTPUT
        fgdel
        cat "${FZF_INPUT_FILE}"
      }
      When call offer
      The output should eq feat
    End

    It 'deletes the selected branch'
      del() {
        git_repo
        git branch feat
        FZF_OUTPUT=feat fgdel > /dev/null
        git branch --list feat
      }
      When call del
      The output should eq ''
    End

    It 'needs -f for an unmerged branch'
      force() {
        git_repo
        git checkout -q -b wip
        git commit -q --allow-empty -m wip
        git checkout -q main
        FZF_OUTPUT=wip fgdel 2> /dev/null
        local plain=$?
        FZF_OUTPUT=wip fgdel -f > /dev/null
        print -r -- "${plain}|$?|$(git branch --list wip)"
      }
      When call force
      The output should eq '1|0|'
    End
  End

  Describe 'previews'
    It 'fgsw shows the log of the highlighted branch'
      preview() {
        git_repo
        unset FZF_OUTPUT
        fgsw
        run_preview main
      }
      When call preview
      The output should include 'init'
    End

    It 'fgl shows the highlighted commit'
      preview() {
        git_repo
        unset FZF_OUTPUT
        fgl
        run_preview "$(git rev-parse HEAD)"
      }
      When call preview
      The output should include 'init'
    End

    It 'fgfix shows the highlighted commit'
      preview() {
        git_repo
        echo x > a.txt
        git add a.txt
        unset FZF_OUTPUT
        fgfix
        run_preview "$(git rev-parse HEAD)"
      }
      When call preview
      The output should include 'init'
    End

    It 'fgdel shows the log of the highlighted branch'
      preview() {
        git_repo
        git branch feat
        unset FZF_OUTPUT
        fgdel
        run_preview feat
      }
      When call preview
      The output should include 'init'
    End

    It 'fgst shows the highlighted stash'
      preview() {
        git_repo
        echo a > f
        git add f
        git commit -q -m add
        echo changed > f
        git stash -q
        unset FZF_OUTPUT
        fgst
        run_preview 'stash@{0}: WIP on main: abc1234 add'
      }
      When call preview
      The output should include 'changed'
    End

    It 'fgl binds ctrl-y to the configured copy command'
      bind() {
        git_repo
        unset FZF_OUTPUT
        fgl
        grep -F "ctrl-y:execute-silent(printf %s {1} | ${_fzf_clipcopy})+abort" "${FZF_ARGS_FILE}"
      }
      When call bind
      The status should be success
      The output should be present
    End
  End

  Describe 'fgfix'
    It 'refuses when nothing is staged'
      none() { git_repo; fgfix; }
      When call none
      The status should eq 1
      The stderr should eq 'fgfix: nothing is staged'
    End

    It 'commits the staged changes as a fixup of the selected commit'
      fix() {
        git_repo
        echo x > a.txt
        git add a.txt
        FZF_OUTPUT="$(git rev-parse HEAD)	init" fgfix > /dev/null
        git log -1 --format=%s
      }
      When call fix
      The output should eq 'fixup! init'
    End
  End

  Describe 'fgl'
    It 'lists the commits'
      log() {
        git_repo
        unset FZF_OUTPUT
        fgl
        cat "${FZF_INPUT_FILE}"
      }
      When call log
      The output should include 'init'
    End
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
    entry=$'\nSEL\nstash@{0}: WIP on main: abc1234 add'

    It 'applies the stash and keeps it'
      apply() {
        stash_repo
        FZF_OUTPUT="${entry/SEL/ctrl-a}" fgst > /dev/null
        print -r -- "$(cat f)|$(git stash list | wc -l | tr -d ' ')"
      }
      When call apply
      The output should eq 'b|1'
    End

    It 'pops the stash'
      pop() {
        stash_repo
        FZF_OUTPUT="${entry/SEL/ctrl-p}" fgst > /dev/null
        print -r -- "$(cat f)|$(git stash list | wc -l | tr -d ' ')"
      }
      When call pop
      The output should eq 'b|0'
    End

    It 'creates a branch from the stash'
      branch() {
        stash_repo
        FZF_OUTPUT="${entry/SEL/ctrl-b}" fgst > /dev/null 2>&1
        git branch --list 'stash-abc1234'
      }
      When call branch
      The output should include 'stash-abc1234'
    End

    It 'drops the stash and asks again'
      drop() {
        stash_repo
        echo c > f
        git stash -q
        fzf_seq "${entry/SEL/del}" ''
        fgst > /dev/null
        git stash list | wc -l | tr -d ' '
      }
      When call drop
      The output should eq 1
    End

    It 'ignores a key pressed with no stash selected'
      nothing() {
        stash_repo
        fzf_seq $'\nctrl-p\n' ''
        fgst
        git stash list | wc -l | tr -d ' '
      }
      When call nothing
      The output should eq 1
    End

    It 'leaves the stash alone on a plain enter'
      enter() {
        stash_repo
        FZF_OUTPUT=$'\n\nstash@{0}: WIP on main: abc1234 add' fgst
        git stash list | wc -l | tr -d ' '
      }
      When call enter
      The output should eq 1
    End

    It 'does nothing when cancelled'
      cancel() {
        stash_repo
        unset FZF_OUTPUT
        fgst
        git stash list | wc -l | tr -d ' '
      }
      When call cancel
      The output should eq 1
    End
  End

  Describe 'fgsw'
    It 'switches to the selected local branch'
      sw() {
        git_repo
        git branch feat
        FZF_OUTPUT=feat fgsw 2> /dev/null
        git branch --show-current
      }
      When call sw
      The output should eq feat
    End

    It 'tracks a remote branch that has no local copy'
      remote() {
        git_repo
        git init -q --bare "${SHELLSPEC_TMPBASE}/remote.git"
        git remote add origin "${SHELLSPEC_TMPBASE}/remote.git"
        git branch feat
        git push -q origin main feat 2> /dev/null
        git branch -q -D feat
        git fetch -q origin
        FZF_OUTPUT=origin/feat fgsw > /dev/null 2>&1
        git branch --show-current
      }
      When call remote
      The output should eq feat
    End
  End
End
