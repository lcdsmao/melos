/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:math' as math;

import 'package:conventional_commit/conventional_commit.dart';
import 'package:pub_semver/pub_semver.dart';

import 'changelog.dart';
import 'package.dart';
import 'versioning.dart' as versioning;

/// Enum representing why the version has been changed when running 'version' command.
enum PackageUpdateReason {
  /// Changed due to a commit modifying code in this package.
  commit,

  /// Changed due to another package that this package depends on being updated.
  dependency,

  /// Package is being graduated to a stable version from a prerelease.
  graduate,
}

class MelosPendingPackageUpdate {
  MelosPendingPackageUpdate(
    this.package,
    this.commits,
    this.reason, {
    this.prerelease = false,
    this.graduate = false,
    this.preid,
  });

  /// Commits that triggered this pending update. Can be empty if
  /// [PackageUpdateReason] is [PackageUpdateReason.dependency].
  final List<ConventionalCommit> commits;

  /// The package that this update will apply to when committed.
  final MelosPackage package;

  /// A reason why this package needs updating.
  final PackageUpdateReason reason;

  /// Whether the next package version will be made a prerelease version.
  final bool prerelease;

  /// If true and the package is currently a prerelease version, the next package version
  /// will graduate to a stable, non-prerelease version.
  final bool graduate;

  /// The prerelease id that will be used for prereleases, e.g. "0.1.0-[preid].1".
  final String preid;

  Changelog get changelog {
    // TODO change log styles can be changed here if supported in future.
    return MelosChangelog(this);
  }

  /// Current version specified in the packages pubspec.yaml.
  Version get currentVersion {
    return package.version;
  }

  /// Next pub version that will occur as part of this package update.
  Version get nextVersion {
    return versioning.nextVersion(currentVersion, semverReleaseType,
        graduate: graduate, preid: preid, prerelease: prerelease);
  }

  /// Taking into account all the commits in this update, what is the highest [SemverReleaseType].
  SemverReleaseType get semverReleaseType {
    if (reason == PackageUpdateReason.dependency) {
      // Version bumps for dependencies should be patches.
      // If the dependencies had breaking changes then this package should have had commits to update it separately.
      return SemverReleaseType.patch;
    }

    if (reason == PackageUpdateReason.graduate) {
      if (currentVersion.patch != 0 && currentVersion.minor == 0) {
        return SemverReleaseType.patch;
      }
      if (currentVersion.patch == 0 && currentVersion.minor != 0) {
        return SemverReleaseType.minor;
      }
      return SemverReleaseType.major;
    }

    return SemverReleaseType.values[commits
        .map((e) => e.semverReleaseType.index)
        .toList()
        .reduce(math.max)];
  }

  @override
  bool operator ==(Object other) {
    return other is MelosPendingPackageUpdate &&
        other.package.name == package.name;
  }

  @override
  String toString() {
    return 'MelosPendingPackageUpdate(packageName: ${package.name}, semverType: $semverReleaseType, currentVersion: $currentVersion, nextVersion: $nextVersion)';
  }

  @override
  int get hashCode => package.name.hashCode;
}
