#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${BOSTON_HACKS_BUILD_DIR:-$project_root/../../work/DerivedData}"

xcodebuild \
  -project "$project_root/BostonHacks.xcodeproj" \
  -scheme BostonHacks \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$build_root" \
  CODE_SIGNING_ALLOWED=NO \
  build
