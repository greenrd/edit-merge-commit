precheck::
	which rerere-train.sh >/dev/null || (echo You need to install rerere-train.sh from the Git contrib directory into a directory in your PATH; exit 1)

install:: precheck
	install edit-merge-commit.sh ~/bin/edit-merge-commit
