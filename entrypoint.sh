#!/bin/bash

[[ ${OCROUTER_VERBOSE} == "true" ]] && VERBOSE="--verbose" || VERBOSE=""
[[ ${OCROUTER_RUNCSD} == "true" ]] && CSD_WRAPPER="--csd-wrapper=/usr/libexec/openconnect/csd-wrapper.sh" || CSD_WRAPPER=""

generate_certs() {
    CERT_DIR=/ocrouter/certs
    TMPL_DIR=/etc/ocrouter/templates
    CA_KEY=${CERT_DIR}/ca-key.pem
    CA_CERT=${CERT_DIR}/ca-cert.pem
    SERVER_KEY=${CERT_DIR}/server-key.pem
    SERVER_CERT=${CERT_DIR}/server-cert.pem
    CLIENT_KEY=${CERT_DIR}/client-key.pem
    CLIENT_CERT=${CERT_DIR}/client-cert.pem

    mkdir -p /ocrouter/certs

    certtool --generate-privkey --outfile ${CA_KEY}
    certtool --generate-self-signed --load-privkey ${CA_KEY} \
             --template ${TMPL_DIR}/ca.tmpl --outfile ${CA_CERT}

    certtool --generate-privkey --outfile ${SERVER_KEY}
    certtool --generate-certificate --load-privkey ${SERVER_KEY} \
             --load-ca-certificate ${CA_CERT} --load-ca-privkey ${CA_KEY} \
             --template ${TMPL_DIR}/server.tmpl --outfile ${SERVER_CERT}
    
    certtool --generate-privkey --outfile ${CLIENT_KEY}
    certtool --generate-certificate --load-privkey ${CLIENT_KEY} \
             --load-ca-certificate ${CA_CERT} --load-ca-privkey ${CA_KEY} \
             --template ${TMPL_DIR}/user.tmpl --outfile ${CLIENT_CERT}
}

case $1 in
    generate)
        generate_certs
        exit 0
        ;;
    
    connect)
        shift
        openconnect ${VERBOSE} ${CSD_WRAPPER} $@
        ;;
    
    *)
        exec $@
        ;;
esac
