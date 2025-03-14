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
# Input variables by environment
#----------------------------------------------------------
# K2HDKC_CLUSTER_NAME				k2hdkc cluster name
# K2HDKC_SERVER_COUNT				count of k2hdkc server node
#
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Check enviroment values
#----------------------------------------------------------
if [ -z "${K2HDKC_CLUSTER_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_CLUSTER_NAME environment is not specified."
	exit 1
fi
if [ -z "${K2HDKC_SERVER_COUNT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_SERVER_COUNT environment is not specified."
	exit 1
fi

#----------------------------------------------------------
# Setup OS_NAME
#----------------------------------------------------------
if [ ! -f /etc/os-release ]; then
	echo "[ERROR] Not found /etc/os-release file."
	exit 1
fi
OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

if echo "${OS_NAME}" | grep -q -i "centos"; then
	echo "[ERROR] Not support ${OS_NAME}."
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
# Check curl command and install
#----------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
	if echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		setup_apt_envirnment
		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 || ! dnf install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	else
		echo "[ERROR] Unknown OS type(${OS_NAME})."
		exit 1
	fi
fi

#----------------------------------------------------------
# Common values
#----------------------------------------------------------
ANTPICKAX_ETC_DIR="/etc/antpickax"
K2HR3_FILE_RESOURCE="k2hr3-resource"

K2HR3_YRN_RESOURCE=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" 2>/dev/null)
CHMPX_MODE=$(echo "${K2HR3_YRN_RESOURCE}" | sed 's#[:/]# #g' | awk '{print $NF}')
INI_FILE="${CHMPX_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

TIMESTAMP=$(date "+%Y%m%d-%H:%M:%S")

COMMAND_FILE="/tmp/command.run"
EXPECTED_FILE="/tmp/command.correct"
RESULT_FILE="/tmp/command.result"

TEST_KEYNAME_BASE="check.${K2HDKC_CLUSTER_NAME}.${TIMESTAMP}.key-"
TEST_VALNAME_BASE="check.${K2HDKC_CLUSTER_NAME}.${TIMESTAMP}.val-"

TEST_KEY_COUNT=$((K2HDKC_SERVER_COUNT * 10))

#----------------------------------------------------------
# Set ini file by update script
#----------------------------------------------------------
/bin/sh "${SCRIPTDIR}"/dbaas-k2hdkc-ini-update.sh >/dev/null 2>&1 &
INI_UPDATE_PROCID=$!

#----------------------------------------------------------
# Run chmpx slave process
#----------------------------------------------------------
#
# Wait for creating ini file
#
while [ ! -f "${INI_FILE_PATH}" ]; do
	sleep 10
done

#
# Stop ini update script
# (The sleep process remains, but finishes by the time this script completes.)
#
kill -HUP "${INI_UPDATE_PROCID}" >/dev/null 2>&1

#
# Run chmpx
#
chmpx -conf "${INI_FILE_PATH}" -d silent >/dev/null >&2 &
CHMPX_PROCID=$!

#----------------------------------------------------------
# Create files for check
#----------------------------------------------------------
#
# Create command file
#
{
	for TMP_NUMBER in $(seq "${TEST_KEY_COUNT}"); do
		echo "sleep 1"
		echo "set ${TEST_KEYNAME_BASE}${TMP_NUMBER} ${TEST_VALNAME_BASE}${TMP_NUMBER}"
		echo "print ${TEST_KEYNAME_BASE}${TMP_NUMBER}"
		echo "rm ${TEST_KEYNAME_BASE}${TMP_NUMBER}"
	done

	echo "quit"

} > "${COMMAND_FILE}"

#
# Create result file for comparing
#
{
	for TMP_NUMBER in $(seq "${TEST_KEY_COUNT}"); do
		echo "> sleep 1"
		echo "> set ${TEST_KEYNAME_BASE}${TMP_NUMBER} ${TEST_VALNAME_BASE}${TMP_NUMBER}"
		echo "> print ${TEST_KEYNAME_BASE}${TMP_NUMBER}"
		echo "\"${TEST_KEYNAME_BASE}${TMP_NUMBER}\" => \"${TEST_VALNAME_BASE}${TMP_NUMBER}\""
		echo "> rm ${TEST_KEYNAME_BASE}${TMP_NUMBER}"
	done

	echo "> quit"
	echo "Quit."

} > "${EXPECTED_FILE}"

#----------------------------------------------------------
# Check Main
#----------------------------------------------------------
cleanup_all()
{
	#
	# Just in case, ini update process will also stop.
	#
	kill -HUP "${INI_UPDATE_PROCID}" "${CHMPX_PROCID}" >/dev/null 2>&1
	sleep 1

	kill -KILL "${INI_UPDATE_PROCID}" "${CHMPX_PROCID}" >/dev/null 2>&1
	sleep 1

	rm -f "${COMMAND_FILE}"
	rm -f "${EXPECTED_FILE}"
	rm -f "${RESULT_FILE}"
}

#
# Wait for update chmpx server connection
#
if [ -z "${CHMPX_MODE}" ] || [ "${CHMPX_MODE}" = "slave" ] || [ "${CHMPX_MODE}" = "SLAVE" ]; then
	CHMPXSTATUS_RING_PARAM="slave"
else
	CHMPXSTATUS_RING_PARAM="servicein"
fi
if ! CHMPXSTATUS_RESULT=$(chmpxstatus -conf "${INI_FILE_PATH}" -wait -live up -ring "${CHMPXSTATUS_RING_PARAM}" -self -nosuspend 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Failed to wait chmpx up."
	cleanup_all
	exit 1
fi
if [ "${CHMPXSTATUS_RESULT}" != "SUCCEED" ]; then
	echo "[ERROR] ${PRGNAME} : Got ${CHMPXSTATUS_RESULT} error by waiting chmpx up."
	cleanup_all
	exit 1
fi

#
# Run k2hdkclinetool
#
if ! k2hdkclinetool -conf "${INI_FILE_PATH}" -perm -run "${COMMAND_FILE}"  > "${RESULT_FILE}"; then
	echo "[ERROR] ${PRGNAME} : Failed to run k2hdkclinetool command."
	cleanup_all
	exit 1
fi

#
# Compare result
#
if ! diff "${EXPECTED_FILE}" "${RESULT_FILE}" >/dev/null 2>&1; then
	echo "[ERROR] ${PRGNAME} : The k2hdkclinetool test result is different from the expected result."
	cleanup_all
	exit 1
fi

#
# Cleanup all
#
cleanup_all

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
echo "[SUCCEED] ${PRGNAME} : No problem K2HDKC DBaaS Cluster."

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
