#!/bin/bash

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
    REVIEWDOG_PATH="$HOME/.bin/reviewdog"

    curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1

    echo "$REVIEWDOG_PATH" >> "$GITHUB_PATH"
    export PATH="$REVIEWDOG_PATH:$PATH"
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

    TFSEC_PATH="$HOME/.bin/tfsec"
    test ! -d "${TFSEC_PATH}" && install -d "${TFSEC_PATH}"
    url="https://github.com/tfsec/tfsec/releases/latest/download/tfsec-$os-$arch"
    if [[ "$os" = "windows" ]]; then
        url+=".exe"
        curl -sfL "$url" --output tfsec.exe
        install tfsec.exe "$TFSEC_PATH"
    else
        curl -sfL "$url" --output tfsec
        install tfsec "$TFSEC_PATH"
    fi

    echo "$TFSEC_PATH" >> "$GITHUB_PATH"
    export PATH="$TFSEC_PATH:$PATH"
echo '::endgroup::'

echo "::group:: Print tfsec version details"
    tfsec --version
echo '::endgroup::'

echo '::group:: Running tfsec with reviewdog 🐶 ...'
    export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
    # shellcheck disable=SC2086
    tfsec --format=checkstyle ${INPUT_FLAGS} . \
    | reviewdog -f=checkstyle -name="tfsec" -reporter="${INPUT_REPORTER}" -level="${INPUT_LEVEL}" -fail-on-error="${INPUT_FAIL_ON_ERROR}" -filter-mode="${INPUT_FILTER_MODE}"

    tfsec_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[1]}" exit_code=$?

    echo "::set-output name=tfsec-return-code::${tfsec_return}"
    echo "::set-output name=reviewdog-return-code::${reviewdog_return}"
echo '::endgroup::'

exit $exit_code
