FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest
ARG USERNAME=researcher

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  poppler-utils \
  dnsutils \
  aggregate \
  jq \
  build-essential \
  pkg-config \
  libhdf5-dev \
  nano \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Rename the existing node user/group to $USERNAME
RUN groupmod -n $USERNAME node && \
  usermod -l $USERNAME -d /home/$USERNAME -m -s /bin/zsh node

# Ensure $USERNAME user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R $USERNAME:$USERNAME /usr/local/share

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
USER $USERNAME

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -a "source /opt/fzf/shell/key-bindings.zsh" \
  -a "source /opt/fzf/shell/completion.zsh" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/$USERNAME-firewall && \
  chmod 0440 /etc/sudoers.d/$USERNAME-firewall
USER $USERNAME

# Install Miniforge
USER root
RUN wget -O Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
  bash Miniforge3.sh -b -p /opt/conda && \
  rm Miniforge3.sh && \
  /opt/conda/bin/conda config --set always_yes yes --set changeps1 no && \
  /opt/conda/bin/conda update -q conda && \
  chown -R $USERNAME:$USERNAME /opt/conda

USER $USERNAME

# Add conda to PATH and initialize for zsh
ENV PATH=/opt/conda/bin:$PATH
RUN /opt/conda/bin/conda init zsh && \
  /opt/conda/bin/conda init bash

# Install conda env
COPY environment.yml .
RUN conda env create --name agent-env --file environment.yml

# Activate agent-env by default
RUN echo "conda activate agent-env" >> ~/.zshrc && \
  echo "conda activate agent-env" >> ~/.bashrc