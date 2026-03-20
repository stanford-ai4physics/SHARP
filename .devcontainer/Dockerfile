# Use the official Conda image
FROM continuumio/miniconda3:latest

ARG TZ
ENV TZ="$TZ"

# Create researcher user
ARG USERNAME=researcher
RUN useradd -m -s /bin/bash $USERNAME && \
  mkdir -p /etc/sudoers.d && \
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
  chmod 0440 /etc/sudoers.d/$USERNAME

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  curl \
  wget \
  ca-certificates \
  openssh-server \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure SSH: create runtime directory and disable password authentication
RUN mkdir -p /run/sshd && \
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
  sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Set up directories with proper permissions
RUN chown -R $USERNAME:$USERNAME /usr/local/share

# Install fzf from GitHub (newer version with full shell integration)
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
  /opt/fzf/install --bin && \
  ln -sf /opt/fzf/bin/fzf /usr/local/bin/fzf

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.claude && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER researcher

# Set the default shell to bash
ENV SHELL=/bin/bash

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Colorful terminal: bash prompt, color aliases, and fzf
RUN { \
  echo ""; \
  echo "# Colorful prompt"; \
  echo "PS1='\\[\\e]0;\\w\\a\\]\\[\\033[01;32m\\]\\u@\\h \\[\\033[01;34m\\]\\w \\[\\033[31m\\]\$(date +%H:%M:%S) \\[\\033[01;36m\\]> \\[\\033[00m\\]'"; \
  echo ""; \
  echo "# Enable color support of ls and handy aliases"; \
  echo 'if [ -x /usr/bin/dircolors ]; then'; \
  echo '    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"'; \
  echo "    alias ls='ls --color=auto'"; \
  echo "    alias grep='grep --color=auto'"; \
  echo "    alias fgrep='fgrep --color=auto'"; \
  echo "    alias egrep='egrep --color=auto'"; \
  echo 'fi'; \
  echo ""; \
  echo "# Persist history"; \
  echo "export PROMPT_COMMAND='history -a'"; \
  echo "export HISTFILE=/commandhistory/.bash_history"; \
  echo ""; \
  echo "# fzf key bindings and completion"; \
  echo "source /opt/fzf/shell/key-bindings.bash"; \
  echo "source /opt/fzf/shell/completion.bash"; \
  } >> /home/researcher/.bashrc

# Install Claude Code (native installer, as researcher user)
ENV PATH="/home/researcher/.local/bin:$PATH"
RUN curl -fsSL https://claude.ai/install.sh | bash

# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  mkdir -p /etc/sudoers.d && \
  echo "researcher ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/researcher-firewall && \
  chmod 0440 /etc/sudoers.d/researcher-firewall

# Copy SSH entrypoint (starts sshd with injected public key, then execs CMD)
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

USER researcher