ARG BASE_IMAGE
FROM $BASE_IMAGE

ARG S6_OVERLAY_VERSION=3.1.3.0
ARG S6_ARCH="x86_64"
ARG MINIFORGE_ARCH="x86_64"
ARG MINIFORGE_VERSION=22.9.0-3

ENV WP_USER plaiful
ENV WP_UID 1000
ENV WP_PREFIX /
ENV HOME /home/$WP_USER
ENV CONDA_DIR /opt/conda
ENV PATH "${CONDA_DIR}/bin:${PATH}"
ENV PLAIFUL_CONDA_ENV_NAME "plaiful"
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME 0

# add user
RUN useradd -M -s /bin/bash -N -u ${WP_UID} ${WP_USER} \
 && mkdir -p ${HOME} \
 && chown -R ${WP_USER}:users ${HOME} \
 && chown -R ${WP_USER}:users /usr/local/bin 

# add base packages
RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get -yq update \
 && apt-get -yq install --no-install-recommends \
    apt-transport-https \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    git \
    gnupg \
    gnupg2 \
    locales \
    lsb-release \
    nano \
    software-properties-common \
    tzdata \
    unzip \
    vim \
    wget \
    zip \
    xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# add kubectl
RUN curl -sL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl

# add conda
RUN mkdir -p ${CONDA_DIR} \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> ${HOME}/.bashrc \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> /etc/profile \
 && echo "conda activate ${PLAIFUL_CONDA_ENV_NAME}" >> ${HOME}/.bashrc \
 && echo "conda activate ${PLAIFUL_CONDA_ENV_NAME}" >> /etc/profile \
 && chown -R ${WP_USER}:users ${CONDA_DIR} \
 && chown -R ${WP_USER}:users ${HOME}

RUN curl -sL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh" -o /tmp/Miniforge3.sh \
 && curl -sL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh.sha256" -o /tmp/Miniforge3.sh.sha256 \
 && echo "$(cat /tmp/Miniforge3.sh.sha256 | awk '{ print $1; }') /tmp/Miniforge3.sh" | sha256sum --check \
 && rm /tmp/Miniforge3.sh.sha256 \
 && /bin/bash /tmp/Miniforge3.sh -b -f -p ${CONDA_DIR} \
 && rm /tmp/Miniforge3.sh \
 && conda config --system --set auto_update_conda false \
 && conda config --system --set show_channel_urls true \
 && echo "conda ${MINIFORGE_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
 && conda update -y -q --all \
 && conda clean -a -f -y \
 && chown -R ${WP_USER}:users ${CONDA_DIR} \
 && chown -R ${WP_USER}:users ${HOME}

# add s6 
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp

RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz \
  && rm /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-${S6_ARCH}.tar.xz /tmp/s6-overlay-symlinks-noarch.tar.xz /tmp/s6-overlay-symlinks-arch.tar.xz

COPY root /

COPY ./scripts/activate_env_vars.sh /opt/plaiful/
COPY ./scripts/deactivate_env_vars.sh /opt/plaiful/

RUN chown -R ${WP_UID}:users /etc/s6-overlay

RUN chmod +x /etc/s6-overlay/s6-rc.d/init-conda/run \
  && chmod +x /opt/plaiful/activate_env_vars.sh \
  && chmod +x /opt/plaiful/deactivate_env_vars.sh

USER ${WP_UID}

ENTRYPOINT ["/init"]