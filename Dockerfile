FROM alpine:3.4
MAINTAINER jasl8r@alum.wpi.edu

ENV OCSERV_VERSION=0.11.7 \

RUN buildDeps="curl g++ gnutls-dev gpgme libev-dev libnl3-dev libseccomp-dev \
		linux-headers linux-pam-dev lz4-dev make readline-dev tar xz" \
	&& set -x \
	&& apk update \
	&& apk add gnutls gnutls-utils iptables ip6tables libev libintl libnl3 libseccomp linux-pam lz4 openssl readline sed \
	&& apk add $buildDeps \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-${OCSERV_VERSION}.tar.xz" -o ocserv.tar.xz \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz \
	&& cd /usr/src/ocserv \
	&& ./configure --prefix=/usr \
	&& make \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cd / \
	&& rm -fr /usr/src/ocserv \
	&& apk del $buildDeps \
	&& rm -rf /var/cache/apk/*

WORKDIR /etc/ocserv

COPY ocserv.conf.template /etc/ocserv/ocserv.conf.template
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME /etc/ocserv/data

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
