#! /bin/sh
commit_to_edit=$1
shift
files_to_edit="$@"

out_tmp_file() {
  out=$(mktemp $1.XXXX)
  shift
  "$@" > "$out"
  trap "trap \"rm \\\"$out\\\"\" EXIT INT TERM" 0
  echo "$out"
}

cat_tmp_file() {
  out_tmp_file "$2.$3" git show "$1:$2"
}

get_original_conflicts() {
  if [ "${commit_to_edit}" = "-w" ]; then
    for file in ${files_to_edit}; do
      mv ${file}{,.tmp}
      git checkout -m ${file}
      mv ${file}{,.conflicts}
      trap "trap \"rm \\\"${file}.conflicts\\\"\" EXIT INT TERM" 0
      echo "${file}.conflicts"
      mv ${file}{.tmp,}
    done
  else
    # Warning: Does not work for octupus merges!
    rev1=HEAD^1
    rev3=HEAD^2
    rev2=$(git merge-base $rev1 $rev3)
    git log -1 | sed '1,/Conflicts:$/d' | while read file; do
      out_tmp_file "${file}.conflicts" git merge-file $(cat_tmp_file $rev1 "$file" 1) $(cat_tmp_file $rev2 "$file" 2) $(cat_tmp_file $rev3 "$file" 3) --stdout
    done
  fi
}

temporarily_change_git_config() {
  trap "trap \"git config $1 \\\"$(git config $1)\\\"\" EXIT INT TERM" 0
  git config $1 "$2"
}

if [ "${commit_to_edit}" = "-w" ]; then
  # Working directory - not committed yet
  ${EDITOR:-${VISUAL:-vi}} ${files_to_edit} $(get_original_conflicts)
  git add ${files_to_edit}
else
  rerere-train.sh ^$commit_to_edit
  short_hash=$(git rev-parse --short $commit_to_edit)
  temporarily_change_git_config rerere.enabled true
  EDITOR="sed -i -e \"s/^pick ${short_hash} /edit ${short_hash} /\" " git rebase -i -p ${commit_to_edit}^
  ${EDITOR:-${VISUAL:-vi}} ${files_to_edit} $(get_original_conflicts)
  git add ${files_to_edit}
  git commit --amend
  git rebase --continue
fi