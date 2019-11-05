# Repository to Git conversion

Convert / migrate repositories to Git

## Usage

Migrate
```
./migrate.sh <type> <type_source> <git_target>
./migrate.sh hg ssh://hg@bitbucket.org/mariusvw/my-repostiroy git@github.com:mariusvw/my-new-repository.git
```

Test commit messages
```
./check.sh <type> <type_source_dir> <git_target_dir>
./check.sh hg my-hg-clone my-git-clone
```

## Why?

This tool was mainly created becaues Bitbucket is going to drop Mercurial.

Because of this people are forced to move to Git.

https://bitbucket.org/blog/sunsetting-mercurial-support-in-bitbucket
