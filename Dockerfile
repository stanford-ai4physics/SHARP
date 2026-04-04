# Base image: claude-nersc provides miniconda3, researcher user, system tools,
# fzf, git-delta, Claude Code, firewall/entrypoint, and /workspace workdir.
FROM docker.io/nollde24/claude-nersc:latest

ENV USERNAME=researcher

USER root

# Make claude binary accessible to non-root users
RUN chmod -R o+rX /root /root/.local

# Create workspace and config directories and set permissions.
# The .bashrc line symlinks ~/.claude to /workspace/._claude at shell start,
# so conversations persist on the mounted workspace volume.
RUN mkdir -p /workspace /home/$USERNAME/.conda && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.conda && \
  echo 'mkdir -p /workspace/._claude && ln -sfn /workspace/._claude ~/.claude && ln -sfn /workspace/._claude.json ~/.claude.json' \
    >> /home/$USERNAME/.bashrc

# Install conda environment as the researcher user so it is writable at runtime
USER $USERNAME
COPY --chown=$USERNAME:$USERNAME environment.yml /tmp/environment.yml
RUN conda env create --prefix /home/$USERNAME/.conda/envs/template \
      --file /tmp/environment.yml && \
    conda clean -afy && \
    rm /tmp/environment.yml

USER researcher
