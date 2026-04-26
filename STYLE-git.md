# Git Style Guide

## Git commit messages

* Use the present tense ("Add feature" not "Added feature").
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...").
* Limit the first line to 72 characters or less.
* Reference issues and pull requests liberally after the first line.
* Consider starting the commit message with an applicable emoji:
    * :art: `:art:` when improving the format/structure of the code
    * :racehorse: `:racehorse:` when improving performance
    * :memo: `:memo:` when writing docs
    * :penguin: `:penguin:` when fixing something on Linux
    * :apple: `:apple:` when fixing something on macOS
    * :checkered_flag: `:checkered_flag:` when fixing something on Windows
    * :bug: `:bug:` when fixing a bug
    * :fire: `:fire:` when removing code or files
    * :green_heart: `:green_heart:` when fixing the CI build
    * :white_check_mark: `:white_check_mark:` when adding tests
    * :arrow_up: `:arrow_up:` when upgrading dependencies
    * :arrow_down: `:arrow_down:` when downgrading dependencies
    * :exclamation: `:exclamation:` when removing warnings or deprecations


## A suggested branching model

If you are a dedicated maintainer on a package, you may be wondering which
branching model to choose for development and maintenance of your code.

If you are a contributor, knowing the branching model of a package may help
you work more smoothly with the maintainer.

There are several options available, including git-flow.

Below is a recommended branching model, but it is only a suggestion. What is
best for the dedicated maintainer(s) is best for the project.

The model below is a brief summary of the
['OneFlow model'](http://endoflineblog.com/oneflow-a-git-branching-model-and-workflow).
This is described here for convenience, but we recommend checking out the
blog article for more justification and reasoning on why the model is the way
it is.


### During development

1. There is only one main branch — you can call it anything, but usually it
   is called `main`.

2. Use temporary branches for features, releases, and bug fixes. These
   temporary branches are used as a convenience to share code with other
   developers and as a backup measure. They are always removed once the
   changes present on them are added to `main`.

3. Features are integrated onto `main` in a way which keeps the history
   linear and simple. A good compromise to the rebase vs. merge-commit debate
   is to first do an interactive rebase of the feature branch on `main`,
   and then do a non-fast-forward merge.
   GitHub's squash-merge option when merging a PR is also fine.

_Feature example:_

```sh
git checkout -b feature/my-feature main

# ... make commits to feature/my-feature to finish the feature ...

git rebase -i main
git checkout main
git merge --no-ff feature/my-feature
git push origin main
git branch -d feature/my-feature
```


### Making new releases

1. Create a new branch for a new release. It branches off from `main` at
   the point that `main` has all the necessary features. This is not
   necessarily the tip of `main`.

2. From then on, new work aimed for the _next_ release is pushed to `main`
   as always, and any necessary changes for the _current_ release are pushed
   to the release branch. Once the release is ready, tag the top of the
   release branch.

3. Tag the top of the release branch with a version number. Then do a typical
   merge of the release branch into `main`. Any changes made during the
   release will now be part of `main`. Delete the release branch.

_Release example:_

```sh
git checkout -b release/2.3.0 9efc5d

# ... make commits to release/2.3.0 to finish the release ...

git tag 2.3.0
git checkout main
git merge release/2.3.0
git push --tags origin main
git branch -d release/2.3.0
git push origin :release/2.3.0
```

Then go to GitHub to make your release available.


### Hot fixes and hot-fix releases

1. When a hot fix is needed, create a hot-fix branch that branches from the
   release tag you want to apply the fix to.

2. Push the needed fixes to the hot-fix branch.

3. When the fix is ready, tag the top of the fix branch with a new release,
   merge it into `main`, then delete the hot-fix branch.

_Hot-fix example:_

```sh
git checkout -b hotfix/2.3.1 2.3.0

# ... add commits which fix the problem ...

git tag 2.3.1
git checkout main
git merge hotfix/2.3.1
git push --tags origin main
git branch -d hotfix/2.3.1
```

**Important:**
There is one special case when finishing a hot-fix branch.
If a release branch has already been cut in preparation for the next release
before the hot fix was finished, merge the hot-fix branch into that release
branch rather than into `main`.


## Sources and acknowledgements

This document is based on:

- [BioJulia--Contributing](https://github.com/BioJulia/Contributing)
