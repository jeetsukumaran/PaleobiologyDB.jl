# Contributing to this organization

Thanks for taking the time to contribute!

The following is a set of guidelines for contributing to packages maintained by
this organization, which are hosted on GitHub.

These are mostly guidelines, not rules.
Use your best judgment, and feel free to propose changes to this document in a
pull request.


## Table of contents

[I just have a quick question](#i-just-have-a-quick-question)

[What should I know before I get started?](#what-should-i-know-before-i-get-started)
  - [Package Conventions](#package-conventions)
  - [Package Maintainers](#package-maintainers)
  - [Administrators](#administrators)
  - [Etiquette and conduct](#etiquette-and-conduct)

[How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting an Enhancement](#suggest-an-enhancement)
  - [Making Pull Requests](#making-pull-requests)
  - [Submitting a Package](#submitting-a-package)
  - [Become a Package Maintainer](#become-a-package-maintainer)

[Additional notes](#additional-notes)
  - [A suggested branching model](STYLE-git.md#a-suggested-branching-model)


## I just have a quick question

Please don't file an issue to ask a question.
You'll get faster results by using the community resources below.

The organization has a community chat server where the community chimes in with
helpful advice if you have questions.
If you just have a question, or a problem not covered by this guide, come on
over to the chat and we'll be happy to help. You may also find help at the
[Bio category of the Julia discourse site](https://discourse.julialang.org/c/domain/bio).


## What should I know before I get started?

### Package conventions

First, be familiar with the official Julia documentation on:

* [Packages](https://julialang.github.io/Pkg.jl/v1/getting-started/)
* [Package Development](https://julialang.github.io/Pkg.jl/v1/creating-packages/)
* [Modules](https://docs.julialang.org/en/v1/manual/modules/)

Package names should be as simple and self-explanatory as possible, avoiding
unnecessary acronyms.

Packages introducing some key type or method/algorithm should be named
accordingly. For example, a package introducing biological sequence types and
functionality to process sequence data might be called "BioSequences".

GitHub repository names for packages in this organization should end in `.jl`,
even though the package name itself does not.
i.e. "BioSequences" is the name of the package, and the name of its GitHub
repository is "BioSequences.jl".

Considerate and simple naming greatly assists people in finding the kind of
package or functionality they are looking for.

Files containing Julia code in packages should end in `.jl`.

All user-facing types and functions (i.e. all types and functions exported from
the module of a package) should be documented.
Documentation regarding specific implementation details that aren't relevant to
users should be in the form of comments. Please *do* comment liberally for
complex pieces of code.

We use [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) to generate
user and developer documentation and host it on the web.
The source markdown files for such manuals are kept in the `docs/src/` folder
of each package repository.

The code in all packages is unit tested. Tests should be organized into
contexts, and into separate files based on module.

Files for tests of a module go into an appropriately named folder within the
`test/` folder in the repository.

Every package should have:

- A contributing guide file (`CONTRIBUTING.md`).
- A manually curated `CHANGELOG.md` file.

If you have questions about the files and layout of a package after reading
through all the contributing guidelines, look at the source tree of a
well-established package in the organization and use it as an example guide.
If questions remain, ask an organization member.

#### Package lifecycles

We use the status badges defined by [repostatus](https://www.repostatus.org/)
to classify the development and maintainership status of each of our packages.
Please familiarize yourself with these.


### Package Maintainers

In order to provide the best possible experience for users, a little bit of
structure and organization is necessary.

Each package is dedicated to introducing a specific data type or algorithm, or
dealing with a specific problem or pipeline.

Therefore, maintenance of the packages is fairly decentralized.
To achieve this, we use the role of a "Package Maintainer".

The maintainer(s) for a given package are listed in the package's `README.md`
file and their contact details (at least their GitHub names) are provided in
the package's `AUTHORS.md` file.

The maintainers of a package are responsible for:

1. Deciding the branching model used and how branches are protected.
2. Reviewing pull requests and issues for that package.
3. Tagging releases at suitable points in the lifetime of the package.
4. Being considerate and of assistance to new contributors, community members,
   and new maintainers.
5. Reporting potential incidents of antisocial behavior to an admin member.

**See the [branching model guide](STYLE-git.md#a-suggested-branching-model)
for extra guidance and suggestions on branching models and tagging releases.**

Package maintainers hold **admin** level access for any package(s) for which
they are listed as maintainer, so new contributors should rest assured they
will not be "giving up" any package they transfer to the organization — they
remain that package's administrator. Package maintainers also have **push**
(but not **admin**) access to all other code packages in the ecosystem.

This allows for a community spirit where maintainers primarily dedicated to
other packages may step in to help resolve a PR or issue.
Newer maintainers and researchers contributing a package can therefore rest
assured that help will always be at hand from the community.

However, if you are a maintainer stepping in to help the maintainer(s) of
another package, please respect them by first offering to help before changing
anything. Also ask before performing advanced and potentially destructive git
operations (e.g. force-pushing to branches, or rewriting branch history).
Please defer to the judgment of the maintainers listed in the README of the
package.


### Administrators

The organization has a select group of members in an Admin team.
This team has administrative access to all repositories.

The admin team is expected to:

1. Respond to and resolve any disputes between contributors.
2. Act as mentors to all other maintainers.
3. Assist maintainers in the upkeep of packages when requested, especially
   when more difficult rebases and history manipulation are required.
4. Some administrators maintain the organization's infrastructure, including
   accounts, billing of any platforms used, and maintenance of any hardware
   owned and used by the organization.


### Etiquette and conduct

The organization maintains a statement of etiquette and conduct
(`CODE_OF_CONDUCT.md`) that all members and contributors are expected to
uphold. Please take the time to read and understand this statement.


## How can I contribute?

### Reporting Bugs

Here we show you how to submit a bug report for a package in this organization.
If you follow the advice here, package maintainers and the community will
better understand your report, be able to reproduce the behaviour, and identify
related problems.


#### Before creating a bug report

Please do the following:

1. Check the GitHub issue list for the package that is giving you problems.

2. If you find an issue already open for your problem, add a comment to let
   everyone know that you are experiencing the same issue.

3. If no **currently open** issue already exists for your problem, create a
   new issue.

   > **Note:** If you find a **Closed** issue that seems like it is the same
   > thing you are experiencing, open a new issue and include a link to the
   > original issue in the body of your new one.


#### How to create a (good) new bug report

Bugs are tracked as [GitHub issues](https://guides.github.com/features/issues/).
After you have determined which repository your bug is related to, create an
issue on that repository and provide the following information by filling in
the issue template (`.github/ISSUE_TEMPLATE.md`).

When creating a bug report, please do the following:

1. **Explain the problem**

   - *Use a clear and descriptive title* for the issue to identify the problem.
   - *Describe the exact steps which reproduce the problem* in as many details
     as possible.
     - Which function or method exactly did you use?
     - What arguments or parameters were used?
     - *Provide a specific example* (including links to pastebin, gists, etc.).
       If you are providing snippets in the issue, use
       [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).

   - *Describe the behaviour you observed after following the steps.*
     - Point out exactly what is the problem with that behaviour.
     - *Explain which behaviour you expected to see instead and why.*
     - *Optionally: include screenshots and animated GIFs* which show you
       following the described steps and clearly demonstrate the problem.
       You can use [LICEcap](https://www.cockos.com/licecap/) to record GIFs
       on macOS and Windows, or
       [silentcast](https://github.com/colinkeenan/silentcast) or
       [byzanz](https://github.com/GNOME/byzanz) on Linux.

2. **Provide additional context for the problem** (some of these may not
   always apply)

   - *Did the problem start happening recently* (e.g. after updating to a new
     version)?
     - If so, *can you reproduce the problem in an older version?*
     - What is the most recent version in which the problem does not happen?

   - *Can you reliably reproduce the issue?* If not:
     - Provide details about how often the problem happens.
     - Provide details about the conditions under which it normally happens.

   - If the problem is related to *working with files*:
     - Does the problem happen for all files, or only some?
     - Does the problem happen only with local or remote files?
     - Does the problem happen for files of a specific type, size, or encoding?

3. **Include details about your configuration and environment**

   - *Which version of the package are you using?*
   - *What is the name and version of the OS you are using?*
   - *Which Julia packages do you have installed?*
   - Are you using local configuration files to customize Julia's behaviour?
     If so, please provide the contents of those files, preferably in a
     [code block](https://help.github.com/articles/markdown-basics/#multiple-lines)
     or with a link to a [gist](https://gist.github.com/).


### Suggest an Enhancement

This section explains how to submit an enhancement proposal for a package.
This includes completely new features as well as minor improvements to
existing functionality.
Following these suggestions will help maintainers and the community understand
your suggestion and find related suggestions.


#### Before submitting an enhancement proposal

* **Check if there is already a package in the organization which provides
  that enhancement.**

* **Determine which package the enhancement should be suggested in.**

* **Perform a cursory issue search** to see if the enhancement has already
  been suggested.
  * If it has not, open a new issue as per the guidance below.
  * If it has:
    * Add a comment to the existing issue instead of opening a new one.
    * If it was closed, take the time to understand why (it is fine to ask),
      and consider whether anything has changed that makes the reason outdated.
      If you can make a convincing case to reconsider the enhancement, feel
      free to open a new issue as per the guidance below.


#### How to submit a (good) new enhancement proposal

Enhancement proposals are tracked as
[GitHub issues](https://guides.github.com/features/issues/).
After determining which package your proposal is related to, create an issue
on that repository and provide the following information by filling in the
issue template (`.github/ISSUE_TEMPLATE.md`).

1. **Explain the enhancement**
   - *Use a clear and descriptive title* for the issue to identify the
     suggestion.
   - *Provide a step-by-step description of the suggested enhancement* in as
     many details as possible.
   - *Provide specific examples to demonstrate the steps*. Include
     copy/pasteable snippets as
     [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).

   - If you want to change current behaviour:
     - Describe the *current* behaviour.
     - *Explain which behaviour you expected* to see instead and *why*.
     - *Will the proposed change alter APIs or existing exposed
       methods/types?* If so, this may cause dependency issues and breakages,
       so the maintainer will need to consider this when versioning the next
       release.

   - *Optionally: include screenshots and animated GIFs.*

2. **Provide additional context for the enhancement**

   - *Explain why this enhancement would be useful* to most users and is not
     something that can or should be implemented as a separate package.

   - *Do you know of other projects where this enhancement exists?*

3. **Include details about your configuration and environment**

   - Specify which *version of the package* you are using.
   - Specify the *name and version of the OS* you are using.


### Making Pull Requests

Julia packages can be developed locally. For information on how to do this,
see this section of the Julia
[documentation](https://julialang.github.io/Pkg.jl/v1/creating-packages/).

Before you start working on code, it is often a good idea to open an
enhancement [suggestion](#suggest-an-enhancement).

Once you decide to start working on code, the first thing to do is make
yourself an account on [GitHub](https://github.com).

Find the repository for the package you want to contribute to, then hit the
'Fork' button to create a forked copy under your own GitHub account. This is
your blank slate to work on, and ensures your work and experiments won't
affect other users of the released and stable package.

From there, clone your fork and work on it locally using git:

```sh
git clone https://github.com/<YOUR_GITHUB_USERNAME>/PackageName.jl.git
```


#### How to make (good) code contributions and new pull requests

1. **In your code changes**

   - **Branch properly!**
     - If you are making a bug fix, check out your bug-fix branch from the
       last release tag.
     - If you are making a feature addition or other enhancement, check out
       your branch from `master`.
     - See the [branching model guide](STYLE-git.md#a-suggested-branching-model)
       for more information, or ask a package maintainer.

   - Follow the [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).

   - Follow the [additional Julia style suggestions](CONTRIBUTING.organization.STYLE-julia.md).

   - Follow the [Julia performance tips](https://docs.julialang.org/en/v1/manual/performance-tips/).

   - Update and add docstrings for new code, consistent with the
     [documentation style guide](https://docs.julialang.org/en/v1/manual/documentation/).

   - Update information in the documentation located in the `docs/src/`
     folder of the repository if necessary.

   - Ensure that unit tests have been added covering your code changes.

   - Ensure that you have added an entry to the `[UNRELEASED]` section of
     the `CHANGELOG.md` file for the package. Use previous entries as an
     example.

   - Optionally, add your name to the "Thanks" section of the repository's
     `AUTHORS.md` file.

   - All changes should be compatible with the latest stable version of Julia.

   - Please comment liberally for complex pieces of internal code to
     facilitate comprehension.

2. **In your pull request**

   - **Use the pull request template** (`.github/PULL_REQUEST_TEMPLATE.md`).

   - *Describe* the changes in the pull request.

   - Provide a *clear, simple, descriptive title*.

   - Do not include issue numbers in the PR title.

   - If you have implemented *new features* or behaviour:
     - *Provide a description of the addition* in as many details as
       possible.
     - *Provide justification of the addition*.
     - *Provide a runnable example of use*. This lets reviewers and others
       try out the feature before it is merged or makes its way to a release.

   - If you have *changed current behaviour*:
     - *Describe the behaviour prior to your changes.*
     - *Describe the behaviour after your changes* and justify why you made
       the changes.
     - *Does your change alter APIs or existing exposed methods/types?*
       If so, this may cause dependency issues and breakages, so the
       maintainer will need to consider this when versioning the next release.
     - If your changes are intended to increase performance, provide the
       results of a simple performance benchmark demonstrating the
       improvement, especially if the changes make code less legible.


#### Reviews and merging

You can open a pull request early and push changes to it until it is ready,
or do all your editing locally and make a pull request only when finished —
the choice is yours.

When your pull request is ready on GitHub, mention one of the maintainers of
the repository in a comment and ask them to review it. You can also use
GitHub's review feature. They will review the code and documentation and
assess it.

Your pull request will be accepted and merged if:

1. The dedicated package maintainers approve the pull request for merging.
2. The automated build system confirms that all unit tests pass without
   issues.

There may be package-specific requirements or guidelines for some packages;
the maintainers will let you know.

It is also possible that reviewers or package maintainers will ask you to
make changes to your pull request before they merge it. Take the time to
understand why any such request has been made, and freely discuss it with the
reviewers. Feedback you receive should be constructive and considerate
(also see [Etiquette and conduct](#etiquette-and-conduct)).


### Submitting a Package

If you have written a package and would like to have it listed under — and
endorsed by — this organization, you are agreeing to:

1. Allowing the organization to have joint ownership of the package.
   This allows members to help you review and merge pull requests and other
   contributions, and help you develop new features.
   This policy ensures that you (as the package author and current
   maintainer) will have good support in maintaining your package to the
   highest possible quality.

2. Going through a joint review and decision on a suitable package name.
   This is usually the original name. However, package authors may be asked
   to rename their package to something more official and discoverable if the
   current name is contentious or non-standard.

To submit your package:

1. Introduce yourself and your package on the community chat server.
2. At this point maintainers will reach out to mentor and vouch for you and
   your package. They will:
   1. Discuss with you a suitable name.
   2. Help you ensure the package meets the code and contribution guidelines
      described here.
   3. Add you to the organization if you wish to become a maintainer.
   4. Transfer ownership of the package.


### Become a Package Maintainer

You may ask the current admin or maintainers of a package to invite you.

They will generally be willing to do so if you have done one or more of the
following:

1. [Submitted a new package](#submitting-a-package) to the organization.
2. [Reported a bug](#reporting-bugs).
3. [Suggested an enhancement](#suggest-an-enhancement).
4. [Made one or more pull requests](#making-pull-requests) implementing:
   - Fixed bugs.
   - Improved performance.
   - Added new functionality.
   - Increased test coverage.
   - Improved documentation.

None of these requirements are set in stone, but a track record of
contribution gives good confidence that you are familiar with the tasks and
responsibilities of maintaining a package used by others, and are willing to
do so.
Any other avenue for demonstrating commitment to the community will also be
considered.


### Members can become administrators

Members of the admin team have often been contributing for a long time and
may even be founders. Becoming an admin does not necessarily require large
amounts of code contributions. Rather, the decision to on-board a member to
an admin position requires a history of using and contributing to the
organization and a positive interaction with the community.
Any member who fulfills this may offer to take on the
[responsibilities listed above](#administrators).


### Financial contributions

We welcome financial contributions in full transparency on our open
collective. Anyone can file an expense. If the expense makes sense for the
development of the community, it will be approved by the core contributors
and the person who filed the expense will be reimbursed.

Backers and sponsors are featured on the organization's web pages and package
repositories as a thank-you for supporting the project.

## Sources and acknowledgements

This document is based on:

- [BioJulia--Contributing](https://github.com/BioJulia/Contributing)