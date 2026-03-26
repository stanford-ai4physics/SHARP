# Base image: claude-nersc provides miniconda3, researcher user, system tools,
# fzf, git-delta, Claude Code, firewall/entrypoint, and /workspace workdir.
FROM docker.io/nollde24/claude-nersc:latest

USER root

# Install conda environment
COPY environment.yml /tmp/environment.yml
RUN conda env create --name template --file /tmp/environment.yml && \
    conda clean -afy && \
    rm /tmp/environment.yml


# Make claude binary accessible to non-root users
RUN chmod -R o+rX /root /root/.local

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.claude && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude

USER researcher
