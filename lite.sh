#!/usr/bin/env bash

{
ARGS="$@"
lite_version() {
#   lite_echo "Gistia Lite Extractor v0.0.1"
lite_echo "v0.0.1"
}

lite_alias_path() {
  lite_echo "$(lite_version_dir old)/alias"
}

lite_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

lite_default_install_dir() {
    printf %s "${HOME}/.lite" || printf %s "${XDG_CONFIG_HOME}/.lite"
}

LITE_DIR="$(lite_default_install_dir)"

lite_init() {
    command cd $LITE_DIR
    command rm -rf .ghrc
    command touch .ghrc
    lite_echo
    lite_echo "=> Gistia Lite Extractor initialized."
    lite_echo
}

lite_config() {
    lite_echo
    lite_echo "=> Gistia Lite Extractor configuration settings.."
    lite_echo
    local db_host
    local db_port
    local db_name
    local db_user
    while true; do
        if [ -z "${db_host}" ]; then
            read -p "   URL to access the Database:" db_host
        elif [ -z "${db_port}" ]; then
            read -p "   Database instance Port:" db_port
        elif [ -z "${db_name}" ]; then
            read -p "   Database Name:" db_name
        elif [ -z "${db_user}" ]; then
            read -p "   Database Username:" db_user
        fi
        if [ -n "${db_host}" ] && [ -n "${db_port}" ] && [ -n "${db_name}" ] && [ -n "${db_user}" ]; then
            break;
        fi
    done
    JSON_CONFIG='{"dbHost":"'"$db_host"'","dbPort":'"$db_port"',"dbName":"'"$db_name"'", "dbUser":"'"$db_user"'"}'
    lite_echo
    lite_echo "=> Salved your Lite Extractor configuration credentials in '${LITE_DIR}/.ghrc'"
    command cd $LITE_DIR
    command echo $JSON_CONFIG > .ghrc
}

lite_reset_config() {
    command cd $LITE_DIR
    command rm -rf .ghrc
    lite_config
}

lite_help() {
    LITE_VERSION="$(lite_version)"
    lite_echo
    lite_echo "Gistia Lite Extractor version (v${LITE_VERSION})"
    lite_echo
    lite_echo 'Usage:'
    lite_echo '  lite --help                                  Show this message'
    lite_echo '  lite --init                                  Initialize the lite extract project creating a client credentials configuration file.'
    lite_echo '  lite --version                               Print out the installed version of lite'
    lite_echo '  lite --config                                Store client database credentials in a configuration file.'
    lite_echo '  lite extract [<args>]                        Run extract data from the client database using the credentials stored by the client.'
    lite_echo '   The following optional arguments, if provided, must appear directly after `lite extract`:'
    lite_echo '    -a                                         Make dataset fileds (provider and client) anonymized.'
    # lite_echo '    -f <file_name>                             Rename the outcome file with the input name passed by the user.'
    lite_echo
    lite_echo 'Note:'
    lite_echo '  to remove, delete, or uninstall lite - just remove the `$LITE_DIR` folder (usually `~/.lite`)'
    lite_echo
}

lite_extract() {
    # command cd $LITE_DIR
    if [ ! -e .ghrc ]; then
        lite_config
    fi
    command clear
    lite_echo "=> Gistia Lite Extractor Config settings.."
    local db_password
    while true; do
        if [ -z "${db_password}" ]; then
            read -p "   Password to access the Database:" db_password
        fi
        if [ -n "${db_password}" ]; then
            break;
        fi
    done
    command clear
    lite_echo "Gistia Lite Extractor is running..."
    if [ -n "${1}" ]; then
        command python "$LITE_DIR"/src/main.py -a --password="${db_password}"
    else
        command python "$LITE_DIR"/src/main.py --password="${db_password}"
    fi
}

lite_auto() {
    local LITE_MODE
    LITE_MODE="${1-}"
    local VERSION
    local LITE_CURRENT
    if [ "_${LITE_MODE}" = '_version' ]; then
        lite_version
    elif [ "_$LITE_MODE" = '_config' ]; then
        lite_echo "=> Lite Extractor Credentials Configuration..."
        command cd $LITE_DIR
        if [ -e .ghrc ] && [ -s .ghrc ]; then
            lite_echo
            lite_echo "You already have credentials configured."
            lite_echo
            read -p "Would you like to change your current credentials? (Y/N): " confirm 
            if [[ $confirm =~ ^[Yy]$ ]]; then
                lite_reset_config
            else
                lite_echo
                lite_echo "Your Lite credentials is Up-to-date."
                lite_echo
                exit 1
            fi
        else
            lite_config
        fi
        lite_echo
        lite_echo "All done."
    elif [ "_$LITE_MODE" = '_help' ]; then
        lite_help
    elif [ "_$LITE_MODE" = '_init' ]; then
        lite_init
    elif [ "_$LITE_MODE" = '_extract' ]; then
        lite_extract "${2-}"
    fi
}

lite() {
    local LITE_AUTO_MODE
    LITE_AUTO_MODE='help'
    local OPTIONAL
    while [ "$#" -ne 0 ]; do
        case "$1" in
        --no-use) LITE_AUTO_MODE='none' ;;
        --version) LITE_AUTO_MODE='version' ;;
        version) LITE_AUTO_MODE='version' ;;
        -v) LITE_AUTO_MODE='version' ;;
        --config) LITE_AUTO_MODE='config' ;;
        config) LITE_AUTO_MODE='config' ;;
        -c) LITE_AUTO_MODE='config' ;;
        --help) LITE_AUTO_MODE='help' ;;
        help) LITE_AUTO_MODE='help' ;;
        -h) LITE_AUTO_MODE='help' ;;
        --init) LITE_AUTO_MODE='init' ;;
        init) LITE_AUTO_MODE='init' ;;
        -i) LITE_AUTO_MODE='init' ;;
        --extract) LITE_AUTO_MODE='extract' ;;
        extract) LITE_AUTO_MODE='extract' ;;
        -e) LITE_AUTO_MODE='extract' ;;
        --no-use) LITE_AUTO_MODE='none' ;;
        esac
        case "$2" in
        --anonymized) OPTIONAL='anonymize' ;;
        -a) OPTIONAL='anonymize' ;;
        esac
        shift
    done
    lite_auto "${LITE_AUTO_MODE}" "${OPTIONAL}"
}

lite "$@"

}
