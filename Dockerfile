FROM ubuntu:22.04

LABEL maintainer="forhire"

# Avoid interactive prompts during install
ARG DEBIAN_FRONTEND=noninteractive

# ARGs for installer versions
ARG IB_GATEWAY_VERSION=stable-standalone
ARG IB_GATEWAY_INSTVER=stable-standalone
ARG IB_CONTROLLER_VERSION=3.22.0
ARG IBAPI_VERSION=1030.01

# ENV defaults
ENV TZ=America/Chicago \
    VNC_PASSWORD=1234 \
    TWS_MAJOR_VRSN=${IB_GATEWAY_INSTVER} \
    IBC_INI=/opt/IBController/IBController.ini \
    IBC_PATH=/opt/IBController \
    TWS_PATH=/root/Jts \
    TWS_CONFIG_PATH=/root/Jts \
    SOCAT_LISTEN_PORT=5003 \
    SOCAT_DEST_PORT=4003 \
    SOCAT_DEST_ADDR=127.0.0.1 \
    HEALTHCHECK_CLIENTID=990 \
    HEALTHCHECK_LISTEN_PORT=4002 \
    HEALTHCHECK_IP=127.0.0.1 \
    IBAPI_VERSION=${IBAPI_VERSION} \
    DISPLAY=:0 \
    USER=root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip xvfb libxtst6 libxrender1 libxi6 x11vnc tightvncserver socat \
    software-properties-common iproute2 ncat python3-pip \
    xfonts-base xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic \
    && rm -rf /var/lib/apt/lists/*

# Install IB Gateway, IBController, IB API
RUN mkdir -p /opt/TWS /opt/IBController /opt/TWS/twsapi && \
    # Download & install IB Gateway (headless)
    cd /opt/TWS && \
    wget https://download2.interactivebrokers.com/installers/ibgateway/${IB_GATEWAY_VERSION}/ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh && \
    chmod +x ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh && \
    echo "/root/Jts/ibgateway/${IB_GATEWAY_INSTVER}" > input.txt && \
    xvfb-run ./ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh < input.txt && \
    rm -f ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh input.txt && \
    \
    # Install IB API
    cd /opt/TWS/twsapi && \
    wget https://interactivebrokers.github.io/downloads/twsapi_macunix.${IBAPI_VERSION}.zip && \
    unzip twsapi_macunix.${IBAPI_VERSION}.zip && \
    cd IBJts/source/pythonclient && \
    python3 -m pip install --no-cache-dir wheel && \
    python3 setup.py bdist_wheel && \
    python3 -m pip install --no-cache-dir dist/*.whl && \
    cd /opt && rm -rf /opt/TWS/twsapi && \
    \
    # Install IBController
    cd /opt/IBController && \
    wget -q https://github.com/IbcAlpha/IBC/releases/download/${IB_CONTROLLER_VERSION}/IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    unzip IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    rm IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    chmod -R u+x ./*.sh ./scripts/*.sh

# Set working directory
WORKDIR /

# Copy entrypoint scripts and configs
COPY runscript.sh /
COPY healthcheck.py /
COPY vnc/xvfb_init /etc/init.d/xvfb
COPY vnc/vnc_init /etc/init.d/vnc
COPY vnc/xvfb-daemon-run /usr/bin/xvfb-daemon-run
COPY ib/IBController.ini /opt/IBController/IBController.ini

# Set permissions
RUN chmod +x /runscript.sh && \
    chmod 755 /usr/bin/xvfb-daemon-run && \
    chmod 755 /etc/init.d/xvfb /etc/init.d/vnc

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD /healthcheck.py -a ${HEALTHCHECK_IP} -p ${HEALTHCHECK_LISTEN_PORT} -c ${HEALTHCHECK_CLIENTID} -r 1

# Expose relevant ports
EXPOSE 5900               # VNC
EXPOSE ${SOCAT_DEST_PORT} # 4003 by default
EXPOSE ${SOCAT_LISTEN_PORT} # 5003 by default

CMD ["/bin/bash", "/runscript.sh"]
