# git-revision tests

## Run All

```
pub run test

```

## Structure

##### integration

Creates repositories in a temp directory and uses real git to run test cases against

```
pub run test test/integration
```

##### unit

Unit tests which do not require git to be installed

```
pub run test test/unit
```

