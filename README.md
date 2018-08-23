# git revision

Git extension to generate a meaningful, human readable revision for each commit in a git repository. 

## Usage

```
> git revision
73_feature/user_profile+0_996321c-dirty
```

```
> git revision --full
versionCode: 73
versionName: 73_feature/user_profile+0_996321c-dirty
baseBranch: master
currentBranch: feature/user_profile
sha1: 996321c8a38c0cd0c9ebeb4e9f82615796005202
sha1Short: 996321c
baseBranchCommitCount first-only: 50
baseBranchCommitCount: 50
baseBranchTimeComponent: 23
featureBranchCommitCount: 0
featureBranchTimeComponent: 0
featureOrigin: 996321c8a38c0cd0c9ebeb4e9f82615796005202
yearFactor: 1000
localChanges: 4 +35 -12
```

### Possible revisions

#### Examples

```
1_a541234

1235+1_1234567

432+43_a342123-dirty

1234_someBranch+43_3423123

1234_someBranch+43_3423123-dirty

1234_feature/topic_branch-something1234_cool+43_3423123-dirty

1234_topic_branch_name+0_3423123-dirty
```

#### Schema

Regex matching any possible revision (above)

```
(\d+)(?>_([\w_\-\/]+))?(?>\+(\d+))?_([0-9a-f]{7})(-dirty)?
```


### Help

```
> git revision -h
git revision creates a useful revision for your project beyond 'git describe'
-h, --help            Print this usage information.
-v, --version         Shows the version information of git revision
-C, --context         <path> Run as if git was started in <path> instead of the current working directory
-b, --baseBranch      The base branch where most of the development happens. Often what is set as baseBranch in github. Only on the baseBranch the revision can become only digits.
                      (defaults to "master")

-y, --yearFactor      revision increment count per year
                      (defaults to "1000")

-d, --stopDebounce    time between two commits which are further apart than this stopDebounce (in hours) will not be included into the timeComponent. A project on hold for a few months will therefore not increase the revision drastically when development starts again.
                      (defaults to "48")

    --full            shows full information about the current revision and extracted information
```

# License

```
Copyright 2018 Pascal Welsch

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
