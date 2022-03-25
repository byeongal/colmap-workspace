FROM nvidia/cuda:11.3.1-devel-ubuntu20.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ENV \
    NB_USER=root \
    SHELL=/bin/bash \
    HOME="/${NB_USER}" \
    USER_GID=0 \
    DISPLAY=:1 \
    TERM=xterm \
    WORKSPACE_HOME=/workspace

# Copy a script that we will use to correct permissions after running certain commands
COPY scripts/clean-layer.sh  /usr/bin/clean-layer.sh
COPY scripts/fix-permissions.sh  /usr/bin/fix-permissions.sh
RUN \
    chmod a+rwx /usr/bin/clean-layer.sh && \
    chmod a+rwx /usr/bin/fix-permissions.sh 

# Install Ubuntu Package
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
	apt-utils \
	ca-certificates \
	curl \
	fonts-liberation \
	locales \
	pandoc \
	run-one \
	sudo \
	tini \
	wget && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    clean-layer.sh

ENV \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Layer cleanup script
COPY scripts/clean-layer.sh  /usr/bin/clean-layer.sh
COPY scripts/fix-permissions.sh  /usr/bin/fix-permissions.sh

# Make clean-layer and fix-permissions executable
RUN chmod a+rwx /usr/bin/clean-layer.sh && chmod a+rwx /usr/bin/fix-permissions.sh

# Install Python
ENV \
    CONDA_DIR=/opt/conda \
    CONDA_ROOT=/opt/conda
ARG \
    PYTHON_VERSION=default \
    CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download

RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    $CONDA_ROOT/bin/conda config --system --set auto_update_conda false && \
    $CONDA_ROOT/bin/conda config --system --set show_channel_urls true && \
    if [[ "${PYTHON_VERSION}" != "default" ]]; then $CONDA_ROOT/bin/mamba install --quiet --yes python="${PYTHON_VERSION}"; fi && \
    # Pin major.minor version of python
    $CONDA_ROOT/bin/mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    $CONDA_ROOT/bin/conda update --all --quiet --yes && \
    $CONDA_ROOT/bin/conda clean --all -f -y && \
    fix-permissions.sh $CONDA_ROOT && \
    clean-layer.sh