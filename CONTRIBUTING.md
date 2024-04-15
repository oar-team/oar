# CONTRIBUTING

Here are some minimal guidelines for OAR's contributors.

## Coding style

For coding style conventions see:

https://perldoc.perl.org/perlstyle

To enforce a coding style, we use Perltidy, a highly configurable code indenter
and reformatter.

The following Perltidy command line was use to format all OAR's Perl code with
some sane rules:

    perltidy -b -bext=/ -nolq -se -vt=1 -sct -vtc=1 -sct -bar -nsfs -baao -l=100 \
      -pt=2 -ce $(find sources/core/qfunctions/ -maxdepth 1 -type f) \
      $(find sources/ -regex '.*\.\(pm\|pl\)')

All these options are well explained in Perltidy's man page.

### Git pre-commit hook

To make sure newly added Perl code is following the chosen style, please
install the git pre-commit hook which will run Perltidy before any commit.

You will need Perltidy installed, with at least the version 20211029.

To install the git pre-commit hook:

    ln -s ../../misc/dev/pre-commit-tidy-hook .git/hooks/pre-commit

## Ignore revisions when using `git blame`

Big bulk changes, like the application of Perltidy to OAR's code, can make
`git blame` useless.
From git 2.23, it is now possible to provide a list of revisions to ignore.
We keep one in the file `misc/dev/git-blame-ignore-revs`.

This list can be used by adding `--ignore-revs-file misc/dev/git-blame-ignore-revs`
to the command line:

    git blame --ignore-revs-file misc/dev/git-blame-ignore-revs sources/core/…

Or by configuring `blame.ignoreRevsFile` with `git config` to avoid extra
typing each time:

    git config blame.ignoreRevsFile misc/dev/git-blame-ignore-revs
