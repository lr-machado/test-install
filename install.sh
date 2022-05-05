#!/usr/bin/env bash

{

lite_has() {
  type "$1" > /dev/null 2>&1
}

lite_grep() {
  GREP_OPTIONS='' command grep "$@"
}

lite_profile_is_bash_or_zsh() {
  local TEST_PROFILE
  TEST_PROFILE="${1-}"
  case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc")
      return
    ;;
    *)
      return 1
    ;;
  esac
}

lite_detect_profile() {
    if [ "${PROFILE-}" = '/dev/null' ]; then
        # the user has specifically requested NOT to have lite touch their profile
        return
    fi

    if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
        lite_echo "${PROFILE}"
        return
    fi

    local DETECTED_PROFILE
    DETECTED_PROFILE=''

    if [ "${SHELL#*bash}" != "$SHELL" ]; then
        if [ -f "$HOME/.bashrc" ]; then
        DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
        DETECTED_PROFILE="$HOME/.bash_profile"
        fi
    elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
        if [ -f "$HOME/.zshrc" ]; then
        DETECTED_PROFILE="$HOME/.zshrc"
        fi
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
        for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"
        do
        if DETECTED_PROFILE="$(lite_try_profile "${HOME}/${EACH_PROFILE}")"; then
            break
        fi
        done
    fi

    if [ -n "$DETECTED_PROFILE" ]; then
        lite_echo "$DETECTED_PROFILE"
    fi
}

lite_echo() {
    command printf %s\\n "$*" 2>/dev/null
}

if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then
    echo 'Error: the install instructions explicitly say to pipe the install script to `bash`; please follow them'
    exit 1
fi

lite_latest_version() {
    lite_echo "v0.0.1"
}

lite_default_install_dir() {
    printf %s "${HOME}/.lite" || printf %s "${XDG_CONFIG_HOME}/.lite"
}

LITE_DIR="$(lite_default_install_dir)"

lite_install_dir() {
    if [ -n "$LITE_DIR" ]; then
        printf %s "${LITE_DIR}"
    else
        lite_default_install_dir
    fi
}

lite_source() {
    local LITE_GITHUB_REPO
    LITE_GITHUB_REPO="gistia/revcycle-lite-extractor"
    LITE_SOURCE_URL="https://github.com/${LITE_GITHUB_REPO}.git"
    lite_echo "$LITE_SOURCE_URL"
}

lite_output_path() {
    lite_echo "=> Creating output folder..."
    command cd ~
    command cd $LITE_DIR
    command mkdir output
}

lite_download() {
    if lite_has "curl"; then
        curl --fail --compressed -q "$@"
    elif lite_has "wget"; then
        # Emulate curl with wget
        ARGS=$(lite_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                                -e 's/--compressed //' \
                                -e 's/--fail //' \
                                -e 's/-L //' \
                                -e 's/-I /--server-response /' \
                                -e 's/-s /-q /' \
                                -e 's/-sS /-nv /' \
                                -e 's/-o /-O /' \
                                -e 's/-C - /-c /')
        # shellcheck disable=SC2086
        eval wget $ARGS
    fi
}

install_lite_from_git() {
    local INSTALL_DIR
    INSTALL_DIR="$(lite_install_dir)"
    local LITE_VERSION
    LITE_VERSION="${LITE_INSTALL_VERSION:-$(lite_latest_version)}"
    local fetch_error
    if [ -d "$INSTALL_DIR/.git" ]; then
        # Updating repo
        lite_echo "=> lite is already installed in $INSTALL_DIR, trying to update using git"
        command printf '\r=> '
        fetch_error="Failed to update lite with $LITE_VERSION, run 'git fetch' in $INSTALL_DIR yourself."
    else
        fetch_error="Failed to fetch origin with $LITE_VERSION. Please report this!"
        lite_echo "=> Downloading lite from git to '$INSTALL_DIR'"
        command printf '\r=> '
        mkdir -p "${INSTALL_DIR}"
        if [ "$(ls -A "${INSTALL_DIR}")" ]; then
        # Initializing repo
        command git init "${INSTALL_DIR}" || {
            lite_echo >&2 'Failed to initialize lite repo. Please report this!'
            exit 2
        }
        command git --git-dir="${INSTALL_DIR}/.git" remote add origin "$(lite_source)" 2> /dev/null \
            || command git --git-dir="${INSTALL_DIR}/.git" remote set-url origin "$(lite_source)" || {
            lite_echo >&2 'Failed to add remote "origin" (or set the URL). Please report this!'
            exit 2
        }
        else
        # Cloning repo
        command git clone -b lmachado/feat/bash-lite-extractor "$(lite_source)" --depth=1 "${INSTALL_DIR}" || {
            lite_echo >&2 'Failed to clone lite repo. Please report this!'
            exit 2
        }
        fi
    fi
    return
}


install_lite_as_script() {
    local INSTALL_DIR
    INSTALL_DIR="$(lite_install_dir)"
    local LITE_SOURCE_LOCAL
    LITE_SOURCE_LOCAL="$(lite_source script)"
    local LITE_EXEC_SOURCE
    LITE_EXEC_SOURCE="$(lite_source script-lite-exec)"
    local LITE_BASH_COMPLETION_SOURCE
    LITE_BASH_COMPLETION_SOURCE="$(lite_source script-lite-bash-completion)"

    # Downloading to $INSTALL_DIR
    mkdir -p "$INSTALL_DIR"
    if [ -f "$INSTALL_DIR/lite.sh" ]; then
        lite_echo "=> lite is already installed in $INSTALL_DIR, trying to update the script"
    else
        lite_echo "=> Downloading lite as script to '$INSTALL_DIR'"
    fi
    lite_download -s "$LITE_SOURCE_LOCAL" -o "$INSTALL_DIR/lite.sh" || {
        lite_echo >&2 "Failed to download '$LITE_SOURCE_LOCAL'"
        return 1
    } &
    lite_download -s "$LITE_EXEC_SOURCE" -o "$INSTALL_DIR/lite-exec" || {
        lite_echo >&2 "Failed to download '$LITE_EXEC_SOURCE'"
        return 2
    } &
    lite_download -s "$LITE_BASH_COMPLETION_SOURCE" -o "$INSTALL_DIR/bash_completion" || {
        lite_echo >&2 "Failed to download '$LITE_BASH_COMPLETION_SOURCE'"
        return 2
    } &
    for job in $(jobs -p | command sort)
    do
        wait "$job" || return $?
    done
    chmod a+x "$INSTALL_DIR/lite-exec" || {
        lite_echo >&2 "Failed to mark '$INSTALL_DIR/lite-exec' as executable"
        return 3
    }
}

lite_create_alias() {
    # lite_echo echo "$(lite_is_zsh)"
    local PROFILE="~/.bashrc"
    if [ -n "${ZSH_VERSION-}" ]; then
        command cd ~
        command echo 'export LITE_DIR=~/.lite' >> ~/.zshrc
        command echo 'alias lite="$LITE_DIR"/lite.sh' >> ~/.zshrc
        command source ~/.zshrc
        return
    fi
    command cd ~
    command echo 'export LITE_DIR=~/.lite' >> ~/.bashrc
    command echo 'alias lite="$LITE_DIR"/lite.sh' >> ~/.bashrc
    command source ~/.bashrc
}

lite_create_conda_env() {
    lite_echo
    lite_echo "=> Downloading conda..."
    command cd ~
    command wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O ~/miniconda.sh
    command bash ~/miniconda.sh -b -p $HOME/miniconda
    # command rm -rf /var/lib/apt/lists/*
    # command wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    #     && mkdir ~/.conda \
    #     && bash Miniconda3-latest-Linux-x86_64.sh -b \
    #     && rm -f Miniconda3-latest-Linux-x86_64.sh
    lite_echo "Creating conda env as lite-extractor..."
    command conda --version
    command conda create -n lite-extractor python=3.10
    lite_echo "Installing conda requirements..."
    command conda init bash && eval "$(conda shell.bash hook)" && conda activate lite-extractor
    command cd $LITE_DIR
    command pip install -r requirements.txt
}

lite_do_install() {
    if [ -n "${LITE_DIR-}" ] && ! [ -d "${LITE_DIR}" ]; then
        if [ -e "${LITE_DIR}" ]; then
            lite_echo >&2 "File \"${LITE_DIR}\" has the same name as installation directory."
            exit 1
        fi
        if [ "${LITE_DIR}" = "$(lite_default_install_dir)" ]; then
            mkdir "${LITE_DIR}"
        else
            lite_echo >&2 "You have \$LITE_DIR set to \"${LITE_DIR}\", but that directory does not exist. Check your profile files and environment."
            exit 1
        fi
    fi

    if [ -z "${METHOD}" ]; then
        # Autodetect install method
        if lite_has git; then
            install_lite_from_git
        elif lite_has curl || lite_has wget; then
            install_lite_as_script
        else
            lite_echo >&2 'You need git, curl, or wget to install lite'
            exit 1
        fi
    elif [ "${METHOD}" = 'git' ]; then
        if ! lite_has git; then
            lite_echo >&2 "You need git to install lite"
            exit 1
        fi
            install_lite_from_git
    elif [ "${METHOD}" = 'script' ]; then
        if ! lite_has curl && ! lite_has wget; then
            lite_echo >&2 "You need curl or wget to install lite"
            exit 1
        fi
            install_lite_as_script
    else
        lite_echo >&2 "The environment variable \$METHOD is set to \"${METHOD}\", which is not recognized as a valid installation method."
        exit 1
    fi
    lite_echo
    local LITE_PROFILE
    LITE_PROFILE="$(lite_detect_profile)"
    local PROFILE_INSTALL_DIR
    PROFILE_INSTALL_DIR="$(lite_install_dir | command sed "s:^$HOME:\$HOME:")"
    SOURCE_STR="\\nexport LITE_DIR=\"${PROFILE_INSTALL_DIR}\"\\n[ -s \"\$LITE_DIR/lite.sh\" ] && \\. \"\$LITE_DIR/lite.sh\"  # This loads lite\\n"
    BASH_OR_ZSH=false
    if [ -z "${LITE_PROFILE-}" ] ; then
        local TRIED_PROFILE
        if [ -n "${PROFILE}" ]; then
            TRIED_PROFILE="${LITE_PROFILE} (as defined in \$PROFILE), "
        fi
        lite_echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
        lite_echo "=> Create one of them and run this script again"
        lite_echo "   OR"
        lite_echo "=> Append the following lines to the correct file yourself:"
        command printf "${SOURCE_STR}"
        lite_echo
    else
        if lite_profile_is_bash_or_zsh "${LITE_PROFILE-}"; then
            BASH_OR_ZSH=true
        fi
        if ! command grep -qc '/lite.sh' "$LITE_PROFILE"; then
            lite_echo "=> Appending lite source string to $LITE_PROFILE"
            command printf "${SOURCE_STR}" >> "$LITE_PROFILE"
        else
            lite_echo "=> lite source string already in ${LITE_PROFILE}"
        fi
    fi

    \. "$(lite_install_dir)/lite.sh"
    lite_echo
    # lite_create_alias
    lite_create_conda_env
    lite_output_path
    lite_echo
    lite_reset
    lite_echo "=> Close and reopen your terminal to start using lite or run the following to use it now:"
    command printf "${SOURCE_STR}"
    lite_echo
}

lite_reset() {
  unset -f lite_has lite_latest_version lite_default_install_dir lite_install_dir \
    lite_source lite_output_path lite_download install_lite_from_git install_lite_as_script \
    lite_create_alias lite_create_conda_env lite_do_install lite_profile_is_bash_or_zsh \
    lite_grep
}

[ "_$LITE_ENV" = "_testing" ] || lite_do_install

}
