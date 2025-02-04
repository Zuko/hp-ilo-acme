#!/usr/bin/env bash
# Simple script for signing HP iLO CSR using DNS Challange (OVH DNS) with acme.sh client
# Dependencies:
# acme.sh         https://github.com/acmesh-official/acme.sh
# jq              https://github.com/jqlang/jq
# curl (>8.3.0)   https://github.com/curl/curl
# openssl         https://github.com/openssl/openssl
#
# v1.0.0  04.02.2025

set -eu # -o pipefail

# Config
SCRIPT_DIR="$(dirname "$0")"

# iLo
FQDN="ilo.example.com"
USERNAME="USER"
PASSWORD='PASSW0RD'

# OVH
# https://github.com/acmesh-official/acme.sh/wiki/How-to-use-OVH-domain-api
_OVH_END_POINT="ovh-eu"							# OVH endpoint
_OVH_AK=""										# Application key
_OVH_AS=""										# Application secret
_OVH_CK=""										# Consumer key

# ACME
_ACME_SEVER="letsencrypt"						# letsencrypt_test -> for testing!

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
			if openssl x509 -in "${SCRIPT_DIR}/${FQDN}/${FQDN}.cer" -noout -checkend 2592000; then
				# Valid
				echo "Valid certificate found, skipping request signing"
				return
			fi
		fi
	else
		ACME_OPTS="--force"
	fi

	echo "Signing CSR"
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
	echo "This will take a while..."
	sleep 10
	while true; do
		curl -sS -k -u ${USERNAME}:${PASSWORD} \
			"https://${FQDN}/redfish/v1/Managers/1/SecurityService/HttpsCert/" | jq -r '.CertificateSigningRequest // empty' > "${SCRIPT_DIR}/${FQDN}.csr"
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

while getopts "fh" OPT; do
	case "${OPT}" in
		f) _FORCE="1" ;;
		h) helpText ;;
		*) helpText ;;
	esac
done

if [[ "${_FORCE:-0}" -eq "0" ]]; then
	# Check if the certificate is expiring soon
	if echo | openssl s_client -servername ${FQDN} -connect ${FQDN}:443 2>/dev/null | openssl x509 -noout -checkend 2592000 -checkhost ${FQDN}; then
		# Valid, bye
		echo "iLO certificate is valid, nothing to do"
	fi
else
	# Expiring in less than one month or forced
	requestCSR
	signCSR
	installCertificate
fi

# EOF
