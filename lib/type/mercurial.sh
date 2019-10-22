echo "[-] Clone Mercurial repository..."
hg clone $source_repository $tmpdir/hg.tmp
if [ $? != "0" ]
then
    echo "[!] Failed to clone Mercurial repository"
    exit 1
fi

cd "$tmpdir/hg.tmp"

echo "[-] Retrieving authors from Mercurial repository..."
hg log | grep '^user:' | sort | uniq | sed 's/user: *//' > $tmpdir/authors.tmp

echo "[-] Merge new found authors with known authors"
cat "$tmpdir/authors.tmp" > "$tmpdir/authors.tmp.new"
if [ -e "$authorfile" ]
then
    cat "$authorfile" | awk -F ' = ' '{ print($1) }' | sort > "$tmpdir/authors.tmp.old"
else
    touch "$tmpdir/authors.tmp.old"
fi

fn_ifs_change
newauthors=$(comm -23 "$tmpdir/authors.tmp.new" "$tmpdir/authors.tmp.old")
if [ "$newauthors" != "" ] || [ ! -e "$authorfile" ]
then
    for author in $newauthors
    do
        echo $author >> "$authorfile"
    done

    read -p "[-] New authors found. Press a key to review and edit them."
    vi "$authorfile"
    read -p "[!] Continue migration? (ctrl-c to stop now)"
fi
fn_ifs_restore

echo "[-] Naming draft branches..."
hg log -r "draft()" -b default > $tmpdir/draft-changesets.tmp
grep 'changeset:' "$tmpdir/draft-changesets.tmp" | awk -F ':' '{ print($2) }' | tr -d ' ' > $tmpdir/draft-revs.tmp
fn_ifs_change
for rev in $(cat $tmpdir/draft-revs.tmp)
do
    echo "[+] created: draft-$rev"
    hg update $rev
    hg branch "draft-$rev"
    hg commit -m "Created branch for draft-$rev"
done
fn_ifs_restore

echo "[-] Update to tip..."
hg update tip

echo "[-] Converting repository to temporary local Git repository..."
mkdir "$tmpdir/git.tmp"
cd "$tmpdir/git.tmp"
git init
git config core.ignoreCase false
$root/lib/fast-export/hg-fast-export.sh -r "$tmpdir/hg.tmp" -A "$authorfile" --mappings-are-raw=True
git checkout HEAD

echo "[-] Push to new upstream..."
git remote add origin "$target_repository"
git push --all
git push --tags

echo "[+] Done."
