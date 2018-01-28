# git revision

Work in progress...

## Usage

```
> git revision
73_feature/user_profile+0-dirty
```

```
> git revision --full
versionCode: 73
versionName: 73_feature/user_profile+0-dirty
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