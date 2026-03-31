# Base image: claude-nersc provides miniconda3, researcher user, system tools,
# fzf, git-delta, Claude Code, firewall/entrypoint, and /workspace workdir.
FROM docker.io/nollde24/claude-nersc:latest

USER root

# Make claude binary accessible to non-root users
RUN chmod -R o+rX /root /root/.local

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.claude /home/$USERNAME/.conda && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude /home/$USERNAME/.conda

# Install conda environment as the researcher user so it is writable at runtime
USER $USERNAME
COPY --chown=$USERNAME:$USERNAME environment.yml /tmp/environment.yml
RUN conda env create --prefix /home/$USERNAME/.conda/envs/template \
      --file /tmp/environment.yml && \
    conda clean -afy && \
    rm /tmp/environment.yml

USER researcher
