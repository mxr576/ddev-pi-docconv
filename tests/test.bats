#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=mxr576/ddev-pi-docconv

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  export CI=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Start the pi container profile
  echo "# Starting pi container profile..." >&3
  run ddev start --profiles=pi
  assert_success

  # Verify PI_DOCCONV_VERSION defaults to "main" inside the pi container
  echo "# Checking if PI_DOCCONV_VERSION defaults to main inside the pi container..." >&3
  run ddev exec -s pi printenv PI_DOCCONV_VERSION
  assert_success
  assert_output "main"

  # Verify we can override PI_DOCCONV_VERSION via .ddev/.env.pi
  echo "# Testing override of PI_DOCCONV_VERSION via .ddev/.env.pi..." >&3
  echo 'PI_DOCCONV_VERSION="custom-override"' >> .ddev/.env.pi
  run ddev restart
  assert_success
  run ddev start --profiles=pi
  assert_success
  run ddev exec -s pi printenv PI_DOCCONV_VERSION
  assert_success
  assert_output "custom-override"

  # Verify pandoc is installed in the container
  echo "# Verifying pandoc in container..." >&3
  run ddev exec -s pi which pandoc
  assert_success

  # Verify libreoffice is installed in the container
  echo "# Verifying libreoffice in container..." >&3
  run ddev exec -s pi which libreoffice
  assert_success

  # Verify poppler-utils (pdfinfo and pdftoppm) in container
  echo "# Verifying poppler-utils in container..." >&3
  run ddev exec -s pi which pdfinfo
  assert_success
  run ddev exec -s pi which pdftoppm
  assert_success

  # Verify docconv is executable inside the container
  echo "# Verifying docconv binary in container..." >&3
  run ddev exec -s pi which docconv
  assert_success

  # Verify ddev docconv --help via host command
  echo "# Testing ddev docconv --help..." >&3
  run ddev docconv --help
  assert_success
  assert_output --partial "convert"
  assert_output --partial "verify"

  # Copy test fixture into project root
  cp "${DIR}/tests/testdata/fixture-1page.md" "${TESTDIR}/fixture-1page.md"

  # Test ddev docconv convert with --to docx,pdf,png --json
  echo "# Testing ddev docconv convert with --to docx,pdf,png --json..." >&3
  run ddev docconv convert fixture-1page.md --to docx,pdf,png --json
  assert_success
  assert_output --partial '"status": "success"'
  assert_output --partial '"pages": 1'
  assert_output --partial 'fixture-1page.docx'
  assert_output --partial 'fixture-1page.pdf'
  assert_output --partial 'fixture-1page-page-1.png'
  assert_file_exist "${TESTDIR}/fixture-1page.docx"
  assert_file_exist "${TESTDIR}/fixture-1page.pdf"
  assert_file_exist "${TESTDIR}/fixture-1page-page-1.png"

  # Test ddev docconv verify with --exact-pages 1 (should succeed)
  echo "# Testing ddev docconv verify with --exact-pages 1..." >&3
  run ddev docconv verify fixture-1page.md --exact-pages 1 --json
  assert_success
  assert_output --partial '"status": "success"'
  assert_output --partial '"pages": 1'

  # Test ddev docconv verify with --exact-pages 2 (should fail)
  echo "# Testing ddev docconv verify with --exact-pages 2..." >&3
  run ddev docconv verify fixture-1page.md --exact-pages 2 --json
  assert_failure
  assert_output --partial '"status": "failed"'
  assert_output --partial "expected exactly 2"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
