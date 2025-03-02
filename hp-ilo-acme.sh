#!/usr/bin/env bash
# Simple script for signing HP iLO CSR using DNS Challange (OVH DNS) with acme.sh client
# Dependencies:
# acme.sh         https://github.com/acmesh-official/acme.sh
# jq              https://github.com/jqlang/jq
# curl (>8.3.0)   https://github.com/curl/curl
# openssl         https://github.com/openssl/openssl
#
# v1.0.1  03.03.2025

set -eu # -o pipefail

# Config
SCRIPT_DIR="$(dirname "$0")"

# iLo
readonly FQDN="ilo.example.com"
readonly USERNAME="USER"
readonly PASSWORD='PA$$W0RD'

# OpenSSL
readonly CHECKEND=2592000 # 1 month in seconds

# OVH
# https://github.com/acmesh-official/acme.sh/wiki/How-to-use-OVH-domain-api
readonly _OVH_END_POINT="ovh-eu" # OVH endpoint
readonly _OVH_AK="xXx" # Application key
readonly _OVH_AS="xXx" # Application secret
readonly _OVH_CK="xXx" # Consumer key

# ACME
readonly _ACME_SEVER="letsencrypt" # letsencrypt_test -> for testing!
# /Config

# Sing CSR
function signCSR {
	# OVH endpoint
	export OVH_END_POINT="${_OVH_END_POINT}"
	# Application key
	export OVH_AK="${_OVH_AK}"
	# Application secret
	export OVH_AS="${_OVH_AS}"
	# Consumer key
	export OVH_CK="${_OVH_CK}"

	if [[ "${_FORCE:-0}" -eq "0" ]]; then
		if [[ -s "${SCRIPT_DIR}/${FQDN}/${FQDN}.csr" ]]; then
			echo "Checking if already signed certificate is valid"
			if openssl x509 -in "${SCRIPT_DIR}/${FQDN}/${FQDN}.cer" -noout -enddate -subject -checkend ${CHECKEND} \
				> >(mapfile -t x509; echo -e "Valid to ${x509[0]#*=} for ${x509[1]#*=CN=}\n${x509[2]}\n"); then
				# Valid
				echo "Valid certificate found, skipping request signing"
				return
			fi
		fi
	else
		ACME_OPTS="--force"
	fi

	echo "Signing CSR with ACME.sh"
	if [[ -x "${SCRIPT_DIR}/acme.sh" ]]; then
		"${SCRIPT_DIR}/acme.sh" --signcsr --csr "${SCRIPT_DIR}/${FQDN}.csr" --dns dns_ovh --server ${_ACME_SEVER} --home "${SCRIPT_DIR}" --log-level 1 "${ACME_OPTS}"
	else
		echo "acme.sh is not executable or found"
		exit 1
	fi
}

# Request CSR
function requestCSR {
	if [[ "${_FORCE:-0}" -eq "0" ]]; then
		if [[ -s "${SCRIPT_DIR}/${FQDN}.csr" ]]; then
			echo "Previous CSR found"
			return
		fi
	fi

	# Tell the iLO to start generating private key and certificate signing request
	echo -e "Requesting CSR from iLO"
	curl -sS -k -X POST -H "Content-Type: application/json" \
		--variable "fqdn=${FQDN}" \
		--expand-data '{ "Action": "GenerateCSR", "Country": "X", "State": "X", "City": "X", "OrgName": "X", "OrgUnit": "X", "CommonName": "{{fqdn:json}}" }' \
		-u ${USERNAME}:${PASSWORD} \
		"https://${FQDN}/redfish/v1/Managers/1/SecurityService/HttpsCert/" | jq

	# Attempt to grab the request
	echo "This will take a while…"
	sleep 10
	while true; do
		curl -sS -k -u ${USERNAME}:${PASSWORD} \
			"https://${FQDN}/redfish/v1/Managers/1/SecurityService/HttpsCert/" | jq -r '.CertificateSigningRequest // empty' >"${SCRIPT_DIR}/${FQDN}.csr"
		if [[ -s "${SCRIPT_DIR}/${FQDN}.csr" ]]; then
			break
		else
			sleep 10
		fi
	done
}

# Install signed certificate
function installCertificate {
	# Install certificate and reset iLO
	echo "Installing certificate"
	curl -sS -k -X POST -H "Content-Type: application/json" \
		--variable "certificate@${SCRIPT_DIR}/${FQDN}/${FQDN}.cer" \
		--expand-data '{ "Action": "ImportCertificate", "Certificate": "{{certificate:json}}" }' \
		-u ${USERNAME}:${PASSWORD} \
		"https://${FQDN}/redfish/v1/Managers/1/SecurityService/HttpsCert/" | jq
}

function helpText {
	echo -e "\nUsage: ${0##*/} [-f]"
	echo -e "\t-h\t- This text"
	echo -e "\t-f\t- Force (skip all checks)"
	exit
}

while getopts "f" OPT; do
	case "${OPT}" in
	f) _FORCE="1" ;;
	*) helpText ;;
	esac
done

if [[ "${_FORCE:-0}" -eq "0" ]]; then
	# Check if the certificate is expiring soon
	if openssl x509 -noout -checkend ${CHECKEND} -enddate -subject -in \
		<(openssl s_client -ign_eof -connect "${FQDN}:443" <<<$'HEAD / HTTP/1.0\r\n\r' 2> /dev/null) \
		> >(mapfile -t x509; echo -e "Valid to ${x509[0]#*=} for ${x509[1]#*=CN=}\n${x509[2]}\n"); then
		sleep 1
		# Valid, bye
		echo "Nothing to do this time"
	else
		# Expiring in less than one month
		requestCSR
		signCSR
		installCertificate
	fi
else
	# Forced
	requestCSR
	signCSR
	installCertificate
fi

# EOF
