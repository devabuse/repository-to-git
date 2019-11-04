if [ ! -d "$source_dir/.hg" ] || [ ! -d "$git_dir/.git" ]
then
    echo "Invalid Mercurial or Git repository."
    echo "Usage: $0 <source_dir> <git_dir>"
    exit 1
fi

cd "$source_dir"
hg log -T "{desc}\n\n" -r "ancestors(head() and not closed())" | awk '{$1=$1};1' | grep -v '^$' | sort > "$root/tmp/hg.log"

cd "$git_dir"
git log --format=%B | awk '{$1=$1};1' | grep -v '^$' | sort > "$root/tmp/git.log"

echo "(If all commits are equal you will see no output)"
diff -wby --suppress-common-lines "$root/tmp/hg.log" "$root/tmp/git.log"
