configdir="$root/config/subversion"

echo "[-] Retrieving authors from Subversion repository..."
svn --config-dir "$configdir" log "$source_repository" -q | awk -F '|' '/^r/ {sub("^ ", "", $2); sub(" $", "", $2); print $2" = "$2" <"$2">"}' | sort -u > "$tmpdir/authors.tmp"
awk '{ print($1) }' "$tmpdir/authors.tmp" > "$tmpdir/authors.tmp.new"
if [ -e "$authorfile" ]
then
    awk '{ print($1) }' "$authorfile" | sort > "$tmpdir/authors.tmp.old"
else
    touch "$tmpdir/authors.tmp.old"
fi

fn_ifs_change
newauthors=$(comm -23 "$tmpdir/authors.tmp.new" "$tmpdir/authors.tmp.old")
if [ "$newauthors" != "" ] || [ ! -e "$authorfile" ]
then
    for author in $newauthors
    do
        grep "^$author = " "$tmpdir/authors.tmp" >> "$authorfile"
    done

    read -p "[-] New authors found. Press a key to review and edit them."
    vi "$authorfile"
    read -p "[!] Continue migration? (ctrl-c to stop now)"
fi
fn_ifs_restore

echo "[-] Convert repository to temporary local Git repository."
git svn clone "$source_repository" --no-metadata -A "$authorfile" --stdlayout "$tmpdir/git.tmp"
cd "$tmpdir/git.tmp"
git remote add bare "$target_repository"

echo "[-] Commit Git ignores and externals for each branch."
branches=$(git branch -r | grep ' *origin/' | sed 's/ *origin\///' | grep -v '^tags/')

if [ "$branches" == "" ]
then
    echo "No branches found!"
    exit 1
fi

printf '%s\n' "$branches" | while IFS= read -r branch
do
    branchname="$branch"
    branchpath="branches/$branch"
    if [ "$branch" == "trunk" ]
    then
        branchname="master"
        branchpath="trunk"
        git checkout -q master
    else
        # If branch is not trunk, then we need to add a Subversion remote for it, so we can get the svn::ignore entries.
        git config --add svn-remote.svn.fetch "branches/$branch:refs/remotes/origin/$branch"
        git checkout -q -b "$branch" "remotes/origin/$branch"
    fi

    # Now get the svn::externals entries and commit them to the Git branch.
    echo "[$branchname] Checking out SVN branch '$branchpath'..."
    svn --config-dir "$configdir" co -q "$source_repository/$branchpath" "$tmpdir/svn.tmp"
    if [ $? -ne 0 ]
    then
        echo "[$branchname] ERROR checking out branch, it might not exist anymore in SVN HEAD, perhaps investigate, we skip it."
        continue
    fi
    cd "$tmpdir/svn.tmp"
    externals=$(svn --config-dir "$configdir" st | grep -E "^(X    |    X)   " | cut -c 9-)
    cd "$tmpdir/git.tmp"
    if [ "$externals" != "" ]
    then
        printf '%s\n' "$externals" | while IFS= read -r external
        do
            echo "[$branchname] Adding SVN external '$external' to Git..."
            if [ -d "$tmpdir/svn.tmp/$external" ]
            then
                rm -rf "$tmpdir/svn.tmp/$external/.svn"
            fi
            rm -rf "$tmpdir/git.tmp/$external"

            dirname=$(dirname "$tmpdir/git.tmp/$external")
            mkdir -p "$dirname"
            mv "$tmpdir/svn.tmp/$external" "$tmpdir/git.tmp/$external"
            git add "$tmpdir/git.tmp/$external" > /dev/null
        done

        git commit -q -m "Add files from Subversion externals for branch origin/$branch."
    fi

    # Get the svn:ignore entries and commit them to the Git branch.
    echo "[$branchname] Adding svn:ignore entries to .gitignore..."
    git svn show-ignore --id=origin/trunk > .gitignore
    git add .gitignore > /dev/null
    git commit -q -m "Convert svn:ignore properties to .gitignore for branch origin/$branch."

    # Add .gitkeep to empty directories
    echo "[$branchname] Add .gitkeep to empty directories..."
    find . -type d -empty -print0 | xargs -0 -I % -- touch %/.gitkeep
    find . -type f -name ".gitkeep" -not -path './.git/*' -print0 | xargs -0 git add
    git commit -q -m "Add .gitkeep files to empty directories for branch origin/$branch."

    # Push this branch to upstream.
    git push --set-upstream bare "$branchname"
done

cd "$tmpdir/git.tmp"
git for-each-ref --format="%(refname:short) %(objectname)" refs/remotes/origin/tags | sed 's/^origin\/tags\///' | while IFS= read -r ref
do
    tagname=$(echo "$ref" | rev | cut -f 2- -d " " | rev)
    objectname=$(echo "$ref" | rev | cut -f 1 -d " " | rev)

    # If we are the only commit in the rev list, then we apparently did not create this tag by copying.
    # We cannot link this tag to an existing commit, so we skip it as being invalid.
    if [ $(git rev-list "$objectname" | wc -l) -lt 2 ]
    then
        echo "WARNING: Tag '$tagname' does not have any ancestry, probably not created by an svn copy, skipping..."
        continue
    fi
    git tag "$tagname" "$objectname"
done
git push --tags

echo "All done."
