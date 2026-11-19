# shellcheck shell=sh disable=SC2296,SC2154

Describe '_fzf_menu_load'
  BeforeEach 'load_plugin'

  setup_dir() {
    _fzf_dir="${SHELLSPEC_TMPBASE}/plugin"
    mkdir -p "${_fzf_dir}/functions"
    printf '#!/usr/bin/env zsh\n# desc: Alpha tool\n' > "${_fzf_dir}/functions/alpha"
    printf '#!/usr/bin/env zsh\n# desc: Menu itself\n' > "${_fzf_dir}/functions/fmenu"
    printf '#!/usr/bin/env zsh\n# desc: Private\n' > "${_fzf_dir}/functions/_hidden"
    printf '#!/usr/bin/env zsh\nno description\n' > "${_fzf_dir}/functions/nodesc"
    _fzf_menu=()
  }
  BeforeEach 'setup_dir'

  It 'registers public described functions only'
    load() { _fzf_menu_load && print -r -- "${(okj:,:)_fzf_menu}=${_fzf_menu[alpha]}"; }
    When call load
    The output should eq 'alpha=Alpha tool'
  End
End
