_update_working_branch() {
  local cur="${COMP_WORDS[COMP_CWORD]}"

  if [[ $COMP_CWORD -eq 1 ]]; then
    local branches
    branches=$(git branch -r 2>/dev/null | sed 's|^ *origin/||' | grep -v 'HEAD')
    COMPREPLY=($(compgen -W "$branches" -- "$cur"))
  fi
}

complete -F _update_working_branch update-working-branch
