import 'dart:io' as io;

import 'package:test/test.dart';

import 'util/temp_git.dart';

final DateTime initTime = DateTime.utc(2017, DateTime.january, 10);

void main() {
  group('initialize', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test('no git', () async {
      await git.run(
        name: 'init commit',
        script: sh(
          """
          echo 'Hello World' > a.txt
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 0\n'));
      expect(out, contains('versionName: 0_0000000-dirty\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: null\n'));
      expect(out, contains('sha1: null\n'));
      expect(out, contains('sha1Short: null\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('featureOrigin: null\n'));
      expect(out, contains('yearFactor: 1000\n'));
      expect(out, contains('localChanges: null'));
    });

    test('no commmit', () async {
      await git.run(
        name: 'init commit',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 0\n'));
      expect(out, contains('versionName: 0_0000000-dirty\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: master\n'));
      expect(out, contains('sha1: null\n'));
      expect(out, contains('sha1Short: null\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('featureOrigin: null\n'));
      expect(out, contains('yearFactor: 1000\n'));
      expect(out, contains('localChanges: null'));
    });
  });

  group('orphan branch', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test('first commit', () async {
      git.skipCleanup = true;
      print('cd ${git.repo.path} && fork');
      await git.run(
        name: 'init with 3 commits',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day))}
          """,
        ),
      );

      await git.run(
        name: 'create orphan commit',
        script: sh(
          """
          git checkout --orphan another_root
          echo 'World Hello' > a.txt
          git add a.txt
          
          ${commit("orphan commit", initTime.add(day * 2))}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 0\n'));
      expect(out, contains('versionName: 0_another_root+1_0084417\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: another_root\n'));
      expect(out, contains('sha1: 008441704a1f59649f6dbce4487f9a8747edf124\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 1\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('featureOrigin: null\n'));
      expect(out, contains('yearFactor: 1000\n'));
      expect(out, contains('localChanges: 0 +0 -0'));
    });

    test('3 commits', () async {
      git.skipCleanup = true;
      print('cd ${git.repo.path} && fork');
      await git.run(
        name: 'init with 3 commits',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day))}
          """,
        ),
      );

      await git.run(
        name: 'create orphan commit',
        script: sh(
          """
          git checkout --orphan another_root
          echo 'World Hello' > a.txt
          git add a.txt
          
          ${commit("orphan commit", initTime.add(day * 2))}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(day * 2 + hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day * 3))}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 0\n'));
      expect(out, contains('versionName: 0_another_root+3_f2d44aa\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: another_root\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 3\n'));
      expect(out, contains('featureBranchTimeComponent: 3\n'));
      expect(out, contains('featureOrigin: null\n'));
      expect(out, contains('yearFactor: 1000\n'));
      expect(out, contains('localChanges: 0 +0 -0'));
    });
  });

  group('master only', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test('first commmit', () async {
      await git.run(
        name: 'init commit',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 1\n'));
      expect(out, contains('versionName: 1_b5f9bcd\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: master\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 1\n'));
      expect(out, contains('baseBranchCommitCount: 1\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000'));
    });

    test('3 commits', () async {
      await git.run(
        name: 'init with 3 commits',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day))}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 6\n'));
      expect(out, contains('versionName: 6_f3aacda\n'));
      expect(out, contains('baseBranch: master\n'));
      expect(out, contains('currentBranch: master\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchTimeComponent: 3\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000'));
    });

    test("merge branch with old commits doesn't increase the revision of previous commits", () async {
      await git.run(
        name: 'init master branch',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          """,
        ),
      );

      // get current revision, should not change afterwards
      final out1 = await git.revision(['--full']);
      expect(out1, contains('versionCode: 3'));

      await git.run(
        name: 'merge feature B',
        script: sh(
          """
          # branch from initial commit
          git checkout HEAD^1
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          git checkout featureB
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          
          git checkout master
          ${merge("featureB", initTime.add(day * 2 + (hour * 1)))}
          """,
        ),
      );

      // revision obviously increased after merge
      final out2 = await git.revision(['--full']);
      expect(out2, contains('baseBranchTimeComponent: 6\n'));
      expect(out2, contains('baseBranchCommitCount: 5\n'));
      expect(out2, contains('versionCode: 11\n'));
      expect(out2, contains('versionName: 11_99c52ee\n'));

      await git.run(
        name: 'go back to commit before merge',
        script: sh(
          """
          git checkout master
          git checkout HEAD^1
          """,
        ),
      );

      // same revision as before
      final out3 = await git.revision(['--full']);
      expect(out3, contains('versionCode: 3\n'));
      expect(out3, contains('versionName: 3_51f6726\n'));
    });
  });

  group('main only', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test('first commmit (main)', () async {
      await git.run(
        name: 'init commit',
        script: sh(
          """
          git init
          
          # switch to main
          git checkout -b main
          
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 1\n'));
      expect(out, contains('versionName: 1_b5f9bcd\n'));
      expect(out, contains('baseBranch: main\n'));
      expect(out, contains('currentBranch: main\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 1\n'));
      expect(out, contains('baseBranchCommitCount: 1\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('baseBranchTimeComponent: 0\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000'));
    });

    test('3 commits (main)', () async {
      await git.run(
        name: 'init with 3 commits',
        script: sh(
          """
          git init
          
          # switch to main
          git checkout -b main
          
          echo 'Hello World' > a.txt
          git add a.txt
          
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day))}
          """,
        ),
      );

      final out = await git.revision(['--full']);

      expect(out, contains('versionCode: 6\n'));
      expect(out, contains('versionName: 6_f3aacda\n'));
      expect(out, contains('baseBranch: main\n'));
      expect(out, contains('currentBranch: main\n'));
      expect(out, contains('completeFirstOnlyBaseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchCommitCount: 3\n'));
      expect(out, contains('baseBranchTimeComponent: 3\n'));
      expect(out, contains('featureBranchCommitCount: 0\n'));
      expect(out, contains('featureBranchTimeComponent: 0\n'));
      expect(out, contains('yearFactor: 1000'));
    });

    test("merge branch with old commits doesn't increase the revision of previous commits (main)", () async {
      await git.run(
        name: 'init master branch',
        script: sh(
          """
          git init
          
          # switch to main
          git checkout -b main
         
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          """,
        ),
      );

      // get current revision, should not change afterwards
      final out1 = await git.revision(['--full']);
      expect(out1, contains('versionCode: 3'));

      await git.run(
        name: 'merge feature B',
        script: sh(
          """
          # branch from initial commit
          git checkout HEAD^1
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on main
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          git checkout featureB
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          
          git checkout main
          ${merge("featureB", initTime.add(day * 2 + (hour * 1)))}
          """,
        ),
      );

      // revision obviously increased after merge
      final out2 = await git.revision(['--full']);
      expect(out2, contains('baseBranchTimeComponent: 6\n'));
      expect(out2, contains('baseBranchCommitCount: 5\n'));
      expect(out2, contains('versionCode: 11\n'));
      expect(out2, contains('versionName: 11_99c52ee\n'));

      await git.run(
        name: 'go back to commit before merge',
        script: sh(
          """
          git checkout main
          git checkout HEAD^1
          """,
        ),
      );

      // same revision as before
      final out3 = await git.revision(['--full']);
      expect(out3, contains('versionCode: 3\n'));
      expect(out3, contains('versionName: 3_51f6726\n'));
    });
  });

  group('feature branch', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test("no branch name - fallback to sha1", () async {
      await git.run(
        name: 'init master branch - work on featureB',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          
          # Work on featureB
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """,
        ),
      );

      await git.run(
        name: 'delete feature branch and stay on detached head',
        script: sh(
          """
          git checkout master
          git branch -D featureB
          git checkout 331b280
          """,
        ),
      );

      final out = await git.revision(['--full']);
      expect(out, contains('versionName: 3+2_331b280\n'));
    });

    test("feature branch still has +commits after merge in master", () async {
      await git.run(
        name: 'init master branch - work on featureB',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 6))}
          
          # Work on featureB
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 4))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """,
        ),
      );

      final out = await git.revision(['--full']);
      expect(out, contains('versionName: 3_featureB+2_331b280\n'));

      await git.run(
        name: 'continue work on master and merge featureB',
        script: sh(
          """
          git checkout master
          echo 'third commit' > a.txt
          ${commit("third commit", initTime.add(day + (hour * 2)))}
          
          # Merge feature branch
          ${merge("featureB", initTime.add(day + (hour * 3)))}
          
          # Go back to feature branch
          git checkout featureB
      """,
        ),
      );

      // back on featureB the previous output should not change
      final out2 = await git.revision(['--full']);
      expect(out2, contains('versionName: 3_featureB+2_331b280\n'));
    });

    test("git flow - baseBranch=develop - merge develop -> master increases revision", () async {
      await git.run(
        name: 'init master branch - create develop',
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          
          # Create develop branch
          git checkout -b 'develop'
          """,
        ),
      );

      await git.run(
        name: 'work on feature B',
        script: sh(
          """
          git checkout develop
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """,
        ),
      );

      await git.run(
        name: 'work on feature C',
        script: sh(
          """
          git checkout develop
          git checkout -b 'featureC'
          echo 'implement feature C' > c.txt
          git add c.txt
          ${commit("implement feature C", initTime.add(day + (hour * 4)))}
          
          echo 'fix a bug' > c.txt
          ${commit("fix bug", initTime.add(day * 2))}
          """,
        ),
      );

      await git.run(
        name: 'work on feature D',
        script: sh(
          """
          git checkout develop
          git checkout -b 'featureD'
          echo 'implement feature D' > d.txt
          git add d.txt
          ${commit("implement feature C", initTime.add(day + (hour * 3)))}
          
          echo 'fix more bugs' > d.txt
          ${commit("fix bug", initTime.add(day + (hour * 5)))}
          """,
        ),
      );

      await git.run(
        name: 'merge C then B into develop and release to master',
        script: sh(
          """
          git checkout develop
          ${merge('featureC', initTime.add(day * 2 + (hour * 1)))}
          ${merge('featureB', initTime.add(day * 2 + (hour * 2)))}
          
          git checkout master
          ${merge("develop", initTime.add(day * 2 + (hour * 3)))}
          """,
        ),
      );

      await git.run(
        name: 'merge D into develop and release to master',
        script: sh(
          """
          git checkout develop
          ${merge("featureD", initTime.add(day * 2 + (hour * 4)))}
          
          git checkout master
          ${merge("develop", initTime.add(day * 2 + (hour * 5)))}
          """,
        ),
      );

      // master should be only +2 ahead which are the two merge commits (develop -> master)
      // master will always +1 ahead of develop even when merging (master -> develop)
      final out2 = await git.revision(['--full', '--baseBranch', 'develop']);
      expect(out2, contains('versionName: 17_master+2_a658ff8\n'));
    });
  });

  group('remote', () {
    late TempGit git;
    setUp(() async {
      git = await makeTempGit();
    });

    test("master only on remote", () async {
      final repo2 = await io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(
        name: 'init master branch',
        repo: repo2,
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """,
        ),
      );

      await git.run(
        name: 'clone and implement feature B',
        script: sh(
          """
          git clone ${repo2.path} .
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          # Date is before the last commit on master
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """,
        ),
      );

      final out = await git.revision(['--full']);
      expect(out, contains('versionName: 2_featureB+2_d3e1844\n'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      final out2 = await git.revision(['--full']);
      expect(out2, contains('versionName: 2_featureB+2_d3e1844\n'));
    });

    test("master only on remote which is not called origin", () async {
      final repo2 = await io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(
        name: 'init master branch',
        repo: repo2,
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """,
        ),
      );

      await git.run(
        name: 'clone and implement feature B',
        script: sh(
          """
          git clone -o first ${repo2.path} .
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          ${commit("implement feature B", initTime.add(hour * 6))}
          
          echo 'fix bug' > b.txt
          ${commit("fix bug", initTime.add(day))}
          """,
        ),
      );

      final out = await git.revision(['--full']);
      expect(out, contains('versionName: 2_featureB+2_d3e1844\n'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      final out2 = await git.revision(['--full']);
      expect(out2, contains('versionName: 2_featureB+2_d3e1844\n'));
    });

    test("master only on one remote - multiple remotes", () async {
      final repo2 = await io.Directory("${git.root.path}${io.Platform.pathSeparator}remoteRepo").create();
      await git.run(
        name: 'init master branch',
        repo: repo2,
        script: sh(
          """
          git init
          echo 'Hello World' > a.txt
          git add a.txt
          ${commit("initial commit", initTime)}
          
          echo 'second commit' > a.txt
          ${commit("second commit", initTime.add(hour * 4))}
          """,
        ),
      );

      await git.run(
        name: 'add remotes and start working',
        script: sh(
          """
          git init
          git remote add first ${repo2.path}
          git remote add second ${repo2.path}
          git remote add third ${repo2.path}
          
          git remote add zcorrect ${repo2.path}
          git pull --no-commit zcorrect master
          
          git checkout -b 'featureB'
          echo 'implement feature B' > b.txt
          git add b.txt
          ${commit("implement feature B", initTime.add(hour * 6))}
          """,
        ),
      );

      final out = await git.revision(['--full']);
      expect(out, contains('versionName: 2_featureB+1_9006da1'));

      // now master branch is only available on remote
      await git.run(name: 'delete master branch', script: "git branch -d master");

      // output is unchanged
      final out2 = await git.revision(['--full']);
      expect(out2, contains('versionName: 2_featureB+1_9006da1\n'));
    });
  });
}
