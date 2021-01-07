FROM ubuntu:focal

ENV LIBSRTP_VERSION=2.2.0
ENV LIBNICE_VERSION=0.1.18
ENV LIBWEBSOCKETS_VERSION=v3.2-stable
ENV JANUS_VERSION=v0.10.9

ARG BUILD_SRC="/usr/local/src"

ARG JANUS_CONFIG_DEPS="\
	--prefix=/opt/janus \
	"
ARG JANUS_CONFIG_OPTIONS="\
	--disable-unix-sockets \
	--disable-rabbitmq \
	--disable-mqtt \
	--disable-plugin-lua \
	--disable-plugin-echotest \
	--disable-plugin-recordplay \
	--disable-plugin-textroom \
	--disable-plugin-sip \
	--disable-plugin-nosip \
	--disable-plugin-videocall \
	--disable-plugin-videoroom \
	--disable-plugin-voicemail \
	"
ARG JANUS_BUILD_DEPS_DEV="\
	libcurl4-openssl-dev \
	libjansson-dev \
	libssl-dev \
	libsofia-sip-ua-dev \
	libglib2.0-dev \
	libopus-dev \
	libogg-dev \
	pkg-config \
	libmicrohttpd-dev \
	libconfig-dev \
	gtk-doc-tools \
	meson \
	"
ARG JANUS_BUILD_DEPS_EXT="\
	libavutil-dev \
	libavcodec-dev \
	libavformat-dev \
	gengetopt \
	libtool \
	automake \
	git-core \
	build-essential \
	cmake \
	autoconf \
	curl \
	"

RUN \
	# init build env & install apt deps
	export JANUS_BUILD_DEPS_DEV="${JANUS_BUILD_DEPS_DEV}" && export JANUS_CONFIG_OPTIONS="${JANUS_CONFIG_OPTIONS}"\
	&& /usr/sbin/groupadd -r janus && /usr/sbin/useradd -r -g janus janus \
	&& DEBIAN_FRONTEND=noninteractive apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install apt-utils \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install $JANUS_BUILD_DEPS_DEV ${JANUS_BUILD_DEPS_EXT} sudo ca-certificates \
	# build libnice
	&& git clone https://gitlab.freedesktop.org/libnice/libnice --depth 1 -b ${LIBNICE_VERSION} ${BUILD_SRC}/libnice \
	&& cd ${BUILD_SRC}/libnice \
	&& meson --prefix=/usr build && ninja -C build && sudo ninja -C build install \
	# build libwebsockets 
	&& git clone https://github.com/warmcat/libwebsockets.git ${BUILD_SRC}/libwebsockets \
	&& cd ${BUILD_SRC}/libwebsockets \
	&& git checkout ${LIBWEBSOCKETS_VERSION} \
	&& mkdir ${BUILD_SRC}/libwebsockets/build \
	&& cd ${BUILD_SRC}/libwebsockets/build \
	&& cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" .. \
	&& make \
	&& make install \
	# build libsrtp
	&& git clone https://github.com/cisco/libsrtp.git --depth 1 -b v${LIBSRTP_VERSION} ${BUILD_SRC}/libsrtp \
	&& cd ${BUILD_SRC}/libsrtp \
	&& ./configure --prefix=/usr --enable-openssl \
	&& make shared_library \
	&& make install \
	# build usrsctp
	&& git clone https://github.com/sctplab/usrsctp ${BUILD_SRC}/usrsctp \
	&& cd ${BUILD_SRC}/usrsctp \
	&& ./bootstrap \
	&& ./configure --prefix=/usr --disable-programs --disable-inet --disable-inet6 \
	&& make && sudo make install \
	# build janus
	&& git clone https://github.com/meetecho/janus-gateway.git --depth 1 -b ${JANUS_VERSION} ${BUILD_SRC}/janus-gateway \
	&& cd ${BUILD_SRC}/janus-gateway \
	&& ./autogen.sh \
	&& ./configure ${JANUS_CONFIG_DEPS} $JANUS_CONFIG_OPTIONS  \
	&& make \
	&& make install \
	&& chown -R janus:janus /opt/janus \
	# build cleanup
	&& cd ${BUILD_SRC} \
	&& rm -rf \
	libsrtp \
	janus-gateway \
	libnice \
	usrsctp \
	libwebsockets \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y --auto-remove purge ${JANUS_BUILD_DEPS_EXT} \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y clean \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y autoclean \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
	&& rm -rf /usr/share/locale/* \
	&& rm -rf /var/cache/debconf/*-old \
	&& rm -rf /usr/share/doc/* \
	&& rm -rf /var/lib/apt/*

RUN rm -r /opt/janus/etc/janus/
COPY janus/conf /opt/janus/etc/janus/
COPY janus/certs /opt/janus/etc/janus/
RUN chown janus.janus -R /opt/janus/etc/


ENTRYPOINT ["/opt/janus/bin/janus"]
