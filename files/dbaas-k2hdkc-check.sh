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
# Check curl command and install
#----------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
	if ! command -v apk >/dev/null 2>&1; then
		echo "[ERROR] ${PRGNAME} : This container it not ALPINE, It does not support installations other than ALPINE, so exit."
		exit 1
	fi
	APK_COMMAND=$(command -v apk | tr -d '\n')

	if ! "${APK_COMMAND}" add -q --no-progress --no-cache curl; then
		echo "[ERROR] ${PRGNAME} : Failed to install curl by apk(ALPINE)."
		exit 1
	fi
	if ! command -v curl >/dev/null 2>&1; then
		echo "[ERROR] ${PRGNAME} : Could not install curl by apk(ALPINE)."
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
	kill -KILL "${INI_UPDATE_PROCID}" "${CHMPX_PROCID}" >/dev/null 2>&1
	rm -f "${COMMAND_FILE}"
	rm -f "${EXPECTED_FILE}"
	rm -f "${RESULT_FILE}"
}

#
# Wait for update chmpx server connection
#
sleep 60

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
