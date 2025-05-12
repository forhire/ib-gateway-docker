FROM ubuntu:22.04

LABEL maintainer="forhire"

# Environment configuration
ENV TZ=America/Chicago \
    VNC_PASSWORD=1234 \
    IBC_PATH=/opt/IBController \
    IBC_INI=/opt/IBController/IBController.ini \
    TWS_PATH=/root/Jts \
    TWS_CONFIG_PATH=/root/Jts \
    SOCAT_LISTEN_PORT=5003 \
    SOCAT_DEST_PORT=4003 \
    SOCAT_DEST_ADDR=127.0.0.1 \
    HEALTHCHECK_CLIENTID=990 \
    HEALTHCHECK_LISTEN_PORT=4002 \
    HEALTHCHECK_IP=127.0.0.1 \
    IBAPI_VERSION=1030.01 \
    USER=root \
    DISPLAY=:0

ARG DEBIAN_FRONTEND=noninteractive
ARG IB_GATEWAY_VERSION=stable-standalone
ARG IB_CONTROLLER_VERSION=3.22.0
ARG IB_GATEWAY_INSTVER=stable-standalone

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget unzip xvfb x11vnc tightvncserver socat \
    libxtst6 libxrender1 libxi6 \
    xfonts-base xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic \
    software-properties-common iproute2 ncat \
    python3-pip xinit \
 && rm -rf /var/lib/apt/lists/*

# Install IB Gateway and IB API
RUN mkdir -p /opt/TWS/twsapi && cd /opt/TWS/twsapi && \
    wget https://interactivebrokers.github.io/downloads/twsapi_macunix.${IBAPI_VERSION}.zip && \
    unzip twsapi_macunix.${IBAPI_VERSION}.zip && \
    cd IBJts/source/pythonclient && \
    python3 -m pip install --no-cache-dir wheel && \
    python3 setup.py bdist_wheel && \
    python3 -m pip install --no-cache-dir dist/*.whl && \
    rm -rf /opt/TWS/twsapi

# Install IB Gateway
RUN mkdir -p /opt/TWS && cd /opt/TWS && \
    wget https://download2.interactivebrokers.com/installers/ibgateway/${IB_GATEWAY_VERSION}/ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh && \
    chmod +x ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh && \
    echo -e "/root/Jts/ibgateway/${IB_GATEWAY_INSTVER}\n\n" | ./ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh && \
    rm ibgateway-${IB_GATEWAY_VERSION}-linux-x64.sh

# Install IBController
RUN mkdir -p /opt/IBController/Logs && cd /opt/IBController && \
    wget -q https://github.com/IbcAlpha/IBC/releases/download/${IB_CONTROLLER_VERSION}/IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    unzip IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    rm IBCLinux-${IB_CONTROLLER_VERSION}.zip && \
    chmod -R u+x ./*.sh ./scripts/*.sh

# Copy support scripts and configs
COPY runscript.sh /
COPY healthcheck.py /
COPY ib/IBController.ini /opt/IBController/IBController.ini
COPY vnc/xvfb_init /etc/init.d/xvfb
COPY vnc/vnc_init /etc/init.d/vnc
COPY vnc/xvfb-daemon-run /usr/bin/xvfb-daemon-run

# Permissions
RUN chmod +x /runscript.sh && \
    chmod 755 /usr/bin/xvfb-daemon-run && \
    chmod 755 /etc/init.d/xvfb /etc/init.d/vnc

# Healthcheck to verify API port
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD /healthcheck.py -a ${HEALTHCHECK_IP} -p ${HEALTHCHECK_LISTEN_PORT} -c ${HEALTHCHECK_CLIENTID} -r 1

# Expose ports
EXPOSE 5900
EXPOSE ${SOCAT_DEST_PORT}
EXPOSE ${SOCAT_LISTEN_PORT}

# Entrypoint
CMD ["/bin/bash", "/runscript.sh"]

