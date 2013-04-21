#! /bin/sh
commit_to_edit=$1
shift
files_to_edit="$@"

tmp_dir="$(mktemp -d ".tmp.XXXXXX")"

cleanup() {
  rm -rf "$tmp_dir"
  [ -z $old_git_config_key ] || git config $old_git_config_key $old_git_config_value
}

trap cleanup EXIT INT TERM

out_tmp_file() {
  out="${tmp_dir}/$1"
  shift
  "$@" > "$out"
  echo "$out"
}

cat_tmp_file() {
  out_tmp_file "$2.$3" git show "$1:$2"
}

# Print commit
pc() {
  git log -1 $*
}

# Summarise commit on a single line
sl() {
  pc --oneline $*
}

get_original_conflicts() {
  if [ "${commit_to_edit}" = "-w" ]; then
    for file in ${files_to_edit}; do
      mv ${file}{,.tmp}
      git checkout -m ${file}
      out="${tmp_dir}/${file}.conflicts"
      mv ${file} "${out}"
      echo "${out}"
      mv ${file}{.tmp,}
    done
  else
    # Warning: Does not work for octopus merges!
    rev1=HEAD^1
    rev3=HEAD^2
    rev2=$(git merge-base $rev1 $rev3)
    pc | sed '1,/Conflicts:$/d' | while read file; do
      out_tmp_file "${file}.conflicts" git merge-file -L "$(sl $rev1)" $(cat_tmp_file $rev1 "$file" 1) -L "$(sl $rev2)" $(cat_tmp_file $rev2 "$file" 2) -L "$(sl $rev3)" $(cat_tmp_file $rev3 "$file" 3) --stdout
    done
  fi
}

temporarily_change_git_config() {
  old_git_config_key=$1
  old_git_config_value="$(git config $1)"
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
