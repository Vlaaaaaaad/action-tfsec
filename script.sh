#!/bin/bash

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo '::group:: Installing tfsec ... https://github.com/tfsec/tfsec'
unameOS="$(uname -s)"
case "${unameOS}" in
    Linux*)     os=linux;;
    Darwin*)    os=darwin;;
    CYGWIN*)    os=windows;;
    MINGW*)     os=windows;;
    MSYS_NT*)   os=windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
esac
unameArch="$(uname -m)"
case "${unameArch}" in
    x86*)      arch=amd64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 is supported by tfsec" && exit 1
esac
echo "Detected ${os} running on ${arch}"
mkdir -p ./bin

url="https://github.com/tfsec/tfsec/releases/latest/download/tfsec-$os-$arch"
if [ "$OS" = "windows" ]; then
    url+=".exe"
    curl -sfL "$url" --output tfsec.exe
    mv tfsec ./bin/tfsec.exe
    echo "$(pwd)\bin" >> "$GITHUB_PATH"
else
    curl -sfL "$url" --output tfsec
    chmod +x tfsec
    mv tfsec ./bin/tfsec
    echo "$(pwd)/bin" >> "$GITHUB_PATH"
fi
echo '::endgroup::'


export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

echo '::group:: Running tfsec with reviewdog 🐶 ...'
# shellcheck disable=SC2086
tfsec --format=checkstyle ${INPUT_FLAGS} "${INPUT_WORKING_DIRECTORY}" \
  | reviewdog -f=checkstyle -name="tfsec" -reporter="${INPUT_REPORTER}" -level="${INPUT_LEVEL}" -fail-on-error="${INPUT_FAIL_ON_ERROR}" -filter-mode="${INPUT_FILTER_MODE}"

tfsec_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[1]}" exit_code=$?

echo ::set-output name=tfsec-return-code::"${tfsec_return}"
echo ::set-output name=reviewdog-return-code::"${reviewdog_return}"
echo '::endgroup::'

exit $exit_code