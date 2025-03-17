#!/bin/sh
#
# K2HDKC DBaaS Helm Chart
#
# Copyright 2022 Yahoo Japan Corporation.
#
# K2HDKC DBaaS is a DataBase as a Service provided by Yahoo! JAPAN
# which is built K2HR3 as a backend and provides services in
# cooperation with Kubernetes.
# The Override configuration for K2HDKC DBaaS serves to connect the
# components that make up the K2HDKC DBaaS. K2HDKC, K2HR3, CHMPX,
# and K2HASH are components provided as AntPickax.
#
# For the full copyright and license information, please view
# the license file that was distributed with this source code.
#
# AUTHOR:   Takeshi Nakatani
# CREATE:   Fri Jan 21 2021
# REVISION:
#

#----------------------------------------------------------
# Options
#
#	--register(-reg)	If specified, register with K2HR3 Role
#	--delete(-del)		If specified, remove from K2HR3 Role
#
#----------------------------------------------------------
# Input files
#
# This script loads the following files under '/etc/antpickax'
# directory. These file contents can be used when accessing K2HR3
# REST API.
#
#	K2HR3_FILE_REGISTER_URL		k2hr3 api url with path for
#								registration/deletion
#	K2HR3_FILE_ROLE				yrn full path to the role
#	K2HR3_FILE_ROLE_TOKEN		role token file
#	K2HR3_FILE_APIARG			packed cuk argument("extra=...&cuk=value")
#								to K2HR3 REST API(PUT/GET/DELETE/etc)
#
# CA cert file to K2HR3 API is in secret directory.
#
#	K2HR3_CA_FILE				If the K2HR3 API is HTTPS and is
#								a self-signed certificate, a
#								self-signed CA certificate is
#								required. In this case, this file
#								exists.
#
#----------------------------------------------------------

#----------------------------------------------------------
# Program information
#----------------------------------------------------------
PRGNAME=$(basename "$0")
SRCTOP=$(dirname "$0")
SRCTOP=$(cd "${SRCTOP}" || exit 1; pwd)

#----------------------------------------------------------
# Common Variables
#----------------------------------------------------------
ANTPICKAX_ETC_DIR="/etc/antpickax"
K2HR3_CA_FILE="ca.crt"
K2HR3_FILE_REGISTER_URL="k2hr3-register-url"
K2HR3_FILE_ROLE="k2hr3-role"
K2HR3_FILE_ROLE_TOKEN="k2hr3-role-token"
K2HR3_FILE_APIARG="k2hr3-apiarg"

#----------------------------------------------------------
# Check CA cert
#----------------------------------------------------------
if [ -f "${ANTPICKAX_ETC_DIR}/${K2HR3_CA_FILE}" ]; then
	K2HR3_CA_CERT_OPTION="--cacert"
	K2HR3_CA_CERT_OPTION_VALUE="${ANTPICKAX_ETC_DIR}/${K2HR3_CA_FILE}"
else
	K2HR3_CA_CERT_OPTION=""
	K2HR3_CA_CERT_OPTION_VALUE=""
fi

#----------------------------------------------------------
# Get K2HR3 ROLE TOKEN
#----------------------------------------------------------
if ! K2HDKC_ROLE_TOKEN=$(cat ${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_ROLE_TOKEN} 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Could not load role token from secret." 1>&2
	exit 1
fi

#----------------------------------------------------------
# Get Parameters from files
#----------------------------------------------------------
K2HR3_REGISTER_URL=$(cat "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_REGISTER_URL}" 2>/dev/null)
K2HR3_ROLE=$(cat "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_ROLE}" 2>/dev/null)
K2HR3_APIARG=$(cat "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_APIARG}" 2>/dev/null)

#----------------------------------------------------------
# Setup OS_NAME
#----------------------------------------------------------
if [ ! -f /etc/os-release ]; then
	echo "[ERROR] Not found /etc/os-release file." 1>&2
	exit 1
fi
OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

if echo "${OS_NAME}" | grep -q -i "centos"; then
	echo "[ERROR] Not support ${OS_NAME}." 1>&2
	exit 1
fi

#----------------------------------------------------------
# Utility for ubuntu
#----------------------------------------------------------
IS_SETUP_APT_ENV=0

setup_apt_envirnment()
{
	if [ "${IS_SETUP_APT_ENV}" -eq 1 ]; then
		return 0
	fi
	if [ -n "${HTTP_PROXY}" ] || [ -n "${http_proxy}" ] || [ -n "${HTTPS_PROXY}" ] || [ -n "${https_proxy}" ]; then
		if [ ! -f /etc/apt/apt.conf.d/00-aptproxy.conf ] || ! grep -q -e 'Acquire::http::Proxy' -e 'Acquire::https::Proxy' /etc/apt/apt.conf.d/00-aptproxy.conf; then
			_FOUND_HTTP_PROXY=$(if [ -n "${HTTP_PROXY}" ]; then echo "${HTTP_PROXY}"; elif [ -n "${http_proxy}" ]; then echo "${http_proxy}"; else echo ''; fi)
			_FOUND_HTTPS_PROXY=$(if [ -n "${HTTPS_PROXY}" ]; then echo "${HTTPS_PROXY}"; elif [ -n "${https_proxy}" ]; then echo "${https_proxy}"; else echo ''; fi)

			if [ -n "${_FOUND_HTTP_PROXY}" ] && echo "${_FOUND_HTTP_PROXY}" | grep -q -v '://'; then
				_FOUND_HTTP_PROXY="http://${_FOUND_HTTP_PROXY}"
			fi
			if [ -n "${_FOUND_HTTPS_PROXY}" ] && echo "${_FOUND_HTTPS_PROXY}" | grep -q -v '://'; then
				_FOUND_HTTPS_PROXY="http://${_FOUND_HTTPS_PROXY}"
			fi
			if [ ! -d /etc/apt/apt.conf.d ]; then
				mkdir -p /etc/apt/apt.conf.d
			fi
			{
				if [ -n "${_FOUND_HTTP_PROXY}" ]; then
					echo "Acquire::http::Proxy \"${_FOUND_HTTP_PROXY}\";"
				fi
				if [ -n "${_FOUND_HTTPS_PROXY}" ]; then
					echo "Acquire::https::Proxy \"${_FOUND_HTTPS_PROXY}\";"
				fi
			} >> /etc/apt/apt.conf.d/00-aptproxy.conf
		fi
	fi
	DEBIAN_FRONTEND=noninteractive
	export DEBIAN_FRONTEND

	IS_SETUP_APT_ENV=1

	return 0
}

#----------------------------------------------------------
# Check curl command
#----------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
	#
	# Set files and environments for Ubuntu/Debian
	#
	if echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		setup_apt_envirnment
	fi

	#
	# Install curl with loop
	#
	# [NOTE]
	# The install manager may fail by following error(ex, apk - alpine). In most cases, retrying will solve the problem.
	#   ERROR: Unable to lock database: temporary error (try again later)
	#   ERROR: Failed to open apk database: temporary error (try again later)
	#
	CURL_INSTALLED=0
	RETRY_COUNT=30
	while [ "${CURL_INSTALLED}" -eq 0 ] && [ "${RETRY_COUNT}" -ne 0 ]; do
		if echo "${OS_NAME}" | grep -q -i "alpine"; then
			if apk update -q --no-progress >/dev/null 2>&1 && apk add -q --no-progress --no-cache curl >/dev/null 2>&1; then
				CURL_INSTALLED=1
			fi
		elif echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
			if apt-get update -y -q -q >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1; then
				CURL_INSTALLED=1
			fi
		elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
			if dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 && dnf install -y curl >/dev/null 2>&1; then
				CURL_INSTALLED=1
			fi
		else
			echo "[ERROR] Unknown OS type(${OS_NAME})." 1>&2
			exit 1
		fi
		if [ "${CURL_INSTALLED}" -eq 0 ]; then
			echo "[WARNING] ${PRGNAME} : Failed to install curl on ${OS_NAME}, so retry it" 1>&2
			sleep 2
		else
			if ! command -v curl >/dev/null 2>&1; then
				echo "[WARNING] ${PRGNAME} : Not found installed curl on ${OS_NAME}, so retry it" 1>&2
				CURL_INSTALLED=0
				sleep 2
			fi
		fi
		RETRY_COUNT=$((RETRY_COUNT - 1))
	done
fi
CURL_COMMAND=$(command -v curl | tr -d '\n')

#----------------------------------------------------------
# Parse options
#----------------------------------------------------------
REGISTER_MODE=

while [ $# -ne 0 ]; do
	if [ -z "$1" ]; then
		break

	elif echo "$1" | grep -q -i -e "^-reg$" -e "^--register$"; then
		if [ -n "${REGISTER_MODE}" ]; then
			echo "[ERROR] ${PRGNAME} : already set \"--register(-reg)\" or \"--delete(-del)\" option." 1>&2
			exit 1
		fi
		REGISTER_MODE=1

	elif echo "$1" | grep -q -i -e "^-del$" -e "^--delete$"; then
		if [ -n "${REGISTER_MODE}" ]; then
			echo "[ERROR] ${PRGNAME} : already set \"--register(-reg)\" or \"--delete(-del)\" option." 1>&2
			exit 1
		fi
		REGISTER_MODE=0

	else
		echo "[ERROR] ${PRGNAME} : unknown option($1) is specified." 1>&2
		exit 1
	fi
	shift
done

if [ -z "${REGISTER_MODE}" ]; then
	echo "[ERROR] ${PRGNAME} : specify \"--register(-reg)\" or \"--delete(-del)\" option." 1>&2
	exit 1
fi

#----------------------------------------------------------
# Main process
#----------------------------------------------------------
#
# Call K2HR3 REST API
#
# These file values are used for registration/deletion as follows.
# 	Registration:	curl -s -S ${K2HR3_CA_CERT_OPTION} ${K2HR3_CA_CERT_OPTION_VALUE} -X PUT -H "x-auth-token: R=${K2HDKC_ROLE_TOKEN}" "${K2HR3_REGISTER_URL}/${K2HR3_ROLE}?${K2HR3_APIARG}"
# 	Deletion:		curl -s -S ${K2HR3_CA_CERT_OPTION} ${K2HR3_CA_CERT_OPTION_VALUE} -X DELETE "${K2HR3_REGISTER_URL}/${K2HR3_ROLE}?${K2HR3_APIARG}"
#
if [ "${REGISTER_MODE}" -eq 1 ]; then
	#
	# Registration
	#
	# shellcheck disable=SC2086
	if ! "${CURL_COMMAND}" -s -S ${K2HR3_CA_CERT_OPTION} ${K2HR3_CA_CERT_OPTION_VALUE} -X PUT -H "x-auth-token: R=${K2HDKC_ROLE_TOKEN}" "${K2HR3_REGISTER_URL}/${K2HR3_ROLE}?${K2HR3_APIARG}"; then
		echo "[ERROR] ${PRGNAME} : Failed registration to role member." 1>&2
		exit 1
	fi
else
	#
	# Deletion
	#
	# The Pod(Container) has been registered, so we can access K2HR3 without token to delete it.
	#
	# shellcheck disable=SC2086
	if ! "${CURL_COMMAND}" -s -S ${K2HR3_CA_CERT_OPTION} ${K2HR3_CA_CERT_OPTION_VALUE} -X DELETE "${K2HR3_REGISTER_URL}/${K2HR3_ROLE}?${K2HR3_APIARG}"; then
		echo "[ERROR] ${PRGNAME} : Failed deletion from role member." 1>&2
		exit 1
	fi
fi

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
