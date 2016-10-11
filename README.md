# DCO

[![Build Status](https://img.shields.io/travis/coderanger/dco.svg)](https://travis-ci.org/coderanger/dco)
[![Gem Version](https://img.shields.io/gem/v/dco.svg)](https://rubygems.org/gems/dco)
[![Coverage](https://img.shields.io/codecov/c/github/coderanger/dco.svg)](https://codecov.io/github/coderanger/dco)
[![Gemnasium](https://img.shields.io/gemnasium/coderanger/dco.svg)](https://gemnasium.com/coderanger/dco)
[![License](https://img.shields.io/badge/license-Apache_2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

A command line tool to help manage projects using the [Developer Certificate of Origin](http://developercertificate.org/)
contributor workflow.

## Quick Start

To install:

```bash
gem install dco
```

To enable auto-sign-off for all commits in a repository:

```bash
cd /my/repository
dco enable
```

## Commands

### `dco enable`

The `dco enable` command turns on auto-sign-off for all future commits in a
repository. This means any commit message that does not have `Signed-off-by:`
will have the declaration added. This is equivalent to always using `git commit -s`
even in git tools that do not support it.

The auto-sign-off is implemented using a `commit-msg` hook to rewrite the log
message as needed.

### `dco disable`

The `dco disable` command turns off auto-sign-off, removing the hook script
created by `dco enable`.

### `dco sign`

*Coming soon.*

The `dco sign` command retroactively applies the sign-off commit message to
every commit in a branch. By default it will update the current branch, but you
can provide a branch name via `dco sign BRANCH`.

This can also be used to sign-off a branch on the behalf of another contributor.
You must provide a link to a public declaration that the user is agreeing to the
DCO: `dco sign --behalf https://github.com/me/myproject/pulls/1#issuecomment-238042611`.

## Sponsors

Development sponsored by [Bloomberg](http://www.bloomberg.com/company/technology/).

## License

Copyright 2016, Noah Kantrowitz

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
