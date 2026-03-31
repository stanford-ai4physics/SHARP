#!/usr/bin/env bash
action() {
    # Set main directories
    local shell_is_zsh="$( [ -z "${ZSH_VERSION}" ] && echo "false" || echo "true" )"
    local this_file="$( ${shell_is_zsh} && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
    local this_dir="$( cd "$( dirname "${this_file}" )" && pwd )"

    # set PYTHONPATH
    export PYTHONPATH="${this_dir}/src:${PYTHONPATH}"

    export LAW_HOME="${this_dir}/.law"
    export LAW_CONFIG_FILE="${this_dir}/law.cfg"

    # If no conda available, activate it
    if ! command -v conda >/dev/null 2>&1; then
        module load python
    fi

    # Create or update conda environment from environment.yml
    # Use a user-writable prefix so updates work even when the Docker image
    # pre-installed the env as root under /opt/conda.
    local env_prefix="${HOME}/.conda/envs/template"

    if [ -d "${env_prefix}" ]; then
        # Environment exists in user-writable location — update it
        conda env update --prefix "${env_prefix}" --file="${this_dir}/environment.yml" --prune
    else
        # Create a fresh env in the user-writable location
        conda env create --prefix "${env_prefix}" --file="${this_dir}/environment.yml"
    fi

    # Activate conda environment
    conda activate "${env_prefix}"

    # Load/write config
    CONFIG_FILE="${this_dir}/.config"

    # Function to read the output directory from the config file
    read_config() {
        if [[ -f $CONFIG_FILE ]]; then
            source $CONFIG_FILE
        fi
    }

    # Function to write the output directory to the config file
    write_config() {
        echo "export TEMPLATE_OUT=\"$TEMPLATE_OUT\"" > $CONFIG_FILE
    }

    # Prompt user for input if TEMPLATE_OUT is not set
    prompt_user() {
        # In non-interactive shells (e.g. agent/CI), default without prompting
        if [[ ! -t 0 ]]; then
            export TEMPLATE_OUT="${this_dir}/out"
            write_config
            return
        fi
        read -p "Enter output directory [./out]: " user_input
        user_input=${user_input:-${this_dir}/out}
        if [[ -n $user_input ]]; then
            export TEMPLATE_OUT=$user_input
            write_config
        fi
    }

    # Read config or prompt user
    read_config

    if [[ -z $TEMPLATE_OUT ]]; then
        echo "No output directory configured."
        prompt_user
    fi

    # If output directory somewhere else, set symlink to it
    if [ "$TEMPLATE_OUT" != "${this_dir}/output" ]; then
        ln -sf "$TEMPLATE_OUT" "${this_dir}/output"
    fi

    # law setup
    source "$( law completion )" ""
}
action