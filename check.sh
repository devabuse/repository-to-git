#!/usr/bin/env bash

# Path definitions
devtools_parse_root() {
    local root
    if [ -f "$1" ]
    then
        root="$(cd "$(dirname "$1")"; pwd)"
    else
        root="$1"
    fi
    if [ -L "$root" ]
    then
        root="$(dirname "$root")/$(readlink "$root")"
        devtools_root "$root"
        return
    fi
    echo "$root"
}
devtools_root() {
    [[ $0 != $BASH_SOURCE ]] && devtools_parse_root "${BASH_SOURCE[0]}" || devtools_parse_root "$0"
}
root="$(devtools_root \"$@\")"
cwd=$(pwd)
cd "$root"

source_dir=$2
if [ "${source_dir:0:1}" != '/' ]
then
    source_dir=$cwd/$source_dir
fi
git_dir=$3
if [ "${git_dir:0:1}" != '/' ]
then
    git_dir=$cwd/$git_dir
fi

tmpdir="$root/tmp"

if [ ! -e "$root/lib/check/$1.sh" ]
then
    echo "Type is invalid."
    exit 1
fi

rm -rf "$tmpdir"
mkdir "$tmpdir"

. "$root/lib/common.sh"
. "$root/lib/check/$1.sh"

rm -rf "$tmpdir"
