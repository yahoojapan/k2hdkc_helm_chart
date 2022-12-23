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

#---------------------------------------------------------------
# Input files
#
# This script loads the following files under '/etc/antpickax'
# directory. These file contents can be used when accessing
# K2HR3 REST API.
#
#	K2HR3_FILE_API_URL			k2hr3 api url
#	K2HR3_FILE_RESOURCE			yrn full path to the resource
#	K2HR3_FILE_ROLE_TOKEN		role token file
#	K2HR3_FILE_CUK				cuk value for url argument to
#								K2HR3 REST API(PUT/GET/DELETE/etc)
#
# And use the following files as temporary.
#
#	RESOURCE_TEMP_FILE			temporary file which is downloading
#								the resource fron K2HR3.
#	RESOURCE_COMPARE_CUR_FILE	temporary file for current
#								configuration file to comparing.
#	RESOURCE_COMPARE_NEW_FILE	temporary file for downloaded
#								configuration file to comparing.
#
# This program is started as a daemon. And if it is started from
# other than the terminal, the message will be output to the
# following file under '/var/log'.
#
#	LOG_FILE					output message file
#
# CA cert and host server/client cert files to K2HR3 API is in
# secret directory.
#
#	K2HR3_CA_FILE				If the K2HR3 API is HTTPS and is
#								a self-signed certificate, a
#								self-signed CA certificate is
#								required. In this case, this file
#								exists.
#
#---------------------------------------------------------------

#
# Program information
#
PRGNAME=$(basename "$0")
SRCTOP=$(dirname "$0")
SRCTOP=$(cd "${SRCTOP}" || exit 1; pwd)

#
# Common Variables
#
ANTPICKAX_ETC_DIR="/etc/antpickax"
VAR_LOG_DIR="/var/log"

K2HR3_CA_FILE="ca.crt"

K2HR3_FILE_API_URL="k2hr3-api-url"
K2HR3_FILE_RESOURCE="k2hr3-resource"
K2HR3_FILE_ROLE_TOKEN="k2hr3-role-token"
K2HR3_FILE_CUK="k2hr3-cuk"

RESOURCE_TEMP_FILE="/tmp/${PRGNAME}.$$"
RESOURCE_COMPARE_CUR_FILE="${RESOURCE_TEMP_FILE}.cur"
RESOURCE_COMPARE_NEW_FILE="${RESOURCE_TEMP_FILE}.new"

LOG_FILE="${PRGNAME}.log"

LOOP_SLEEP_SHORT=10
LOOP_SLEEP_ADD=5
LOOP_SLEEP_MAX=60
LOOP_SLEEP_CUR=${LOOP_SLEEP_SHORT}

#
# Utility - Output messgae
#
prn_msg()
{
	MSG_DATE=$(date "+%Y-%m-%d %H:%M:%S")
	if [ -t 1 ]; then
		echo "${MSG_DATE} $*" >> "${VAR_LOG_DIR}"/"${LOG_FILE}"
	else
		echo "${MSG_DATE} $*"
	fi
}

#
# Check curl command
#
# shellcheck disable=SC2034
if ! CURL_COMMAND=$(command -v curl | tr -d '\n'); then
	if ! APK_COMMAND=$(command -v apk | tr -d '\n'); then
		prn_msg "[ERROR] This container it not ALPINE, It does not support installations other than ALPINE, so exit."
		exit 1
	fi
	if ! "${APK_COMMAND}" add -q --no-progress --no-cache curl; then
		prn_msg "[ERROR] Failed to install curl by apk(ALPINE)."
		exit 1
	fi
fi

#
# Main loop - This script is run as daemon
#
FILE_NOT_UPDATED_YET=1
while [ "${FILE_NOT_UPDATED_YET}" -le 1 ]; do
	if [ "${FILE_NOT_UPDATED_YET}" -ne 1 ]; then
		LOOP_SLEEP_CUR=$((LOOP_SLEEP_CUR + LOOP_SLEEP_ADD))
		if [ "${LOOP_SLEEP_MAX}" -lt "${LOOP_SLEEP_CUR}" ]; then
			LOOP_SLEEP_CUR=${LOOP_SLEEP_MAX}
		fi
	fi
	sleep "${LOOP_SLEEP_CUR}"

	#prn_msg "[MESSAGE] Start ----------------------------------------"

	#
	# Check files
	#
	if [ ! -f "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_API_URL}" ]; then
		prn_msg "[ERROR] Not found ${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_API_URL}"
		continue;
	fi
	if [ ! -f "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" ]; then
		prn_msg "[ERROR] Not found ${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}"
		continue;
	fi
	if [ ! -f "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_ROLE_TOKEN}" ]; then
		prn_msg "[ERROR] Not found ${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_ROLE_TOKEN}"
		continue;
	fi
	if [ ! -f "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_CUK}" ]; then
		prn_msg "[ERROR] Not found ${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_CUK}"
		continue;
	fi

	#
	# Check CA cert
	#
	if [ -f "${ANTPICKAX_ETC_DIR}/${K2HR3_CA_FILE}" ]; then
		K2HR3_CA_CERT_OPTION="--cacert"
		K2HR3_CA_CERT_OPTION_VALUE="${ANTPICKAX_ETC_DIR}/${K2HR3_CA_FILE}"
	else
		K2HR3_CA_CERT_OPTION=""
		K2HR3_CA_CERT_OPTION_VALUE=""
	fi

	#
	# Setup variables
	#
	K2HR3_API_URL=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_API_URL}" 2>/dev/null)
	K2HR3_RESOURCE_URL="${K2HR3_API_URL}/v1/resource"

	K2HR3_YRN_RESOURCE=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" 2>/dev/null)
	K2HR3_ROLE_TOKEN=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_ROLE_TOKEN}" 2>/dev/null)
	K2HR3_SELF_CUK=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_CUK}" 2>/dev/null)

	K2HDDKC_MODE=$(echo "${K2HR3_YRN_RESOURCE}" | sed 's#[:/]# #g' | awk '{print $NF}')
	K2HDDKC_INI_FILE="${K2HDDKC_MODE}.ini"
	K2HR3_DATE=$(date -R)

	#
	# Get the resource which is configuration file template
	#
	# shellcheck disable=SC2086
	RESOURCE_STRING=$(curl -s -S -X GET ${K2HR3_CA_CERT_OPTION} ${K2HR3_CA_CERT_OPTION_VALUE} -H "Content-Type: application/json" -H "x-auth-token: R=${K2HR3_ROLE_TOKEN}" "${K2HR3_RESOURCE_URL}/${K2HR3_YRN_RESOURCE}" 2>&1)

	#
	# Check got resource result
	#
	if ! echo "${RESOURCE_STRING}" | tr '[:lower:]' '[:upper:]' | grep '["]*RESULT["]*:[[:space:]]*TRUE[[:space:]]*,' >/dev/null 2>&1; then
		prn_msg "[ERROR] Could not get resource from K2HR3(${K2HR3_RESOURCE_URL}/${K2HR3_YRN_RESOURCE})"
		prn_msg "[ERROR] Result: ${RESOURCE_STRING}"
		continue;
	fi

	#
	# Extract the data part(configuation) from got resource
	#
	echo "${RESOURCE_STRING}" | sed											\
		-e 's/^.*["]*[rR][eE][sS][oO][uU][rR][cC][eE]["]*:[[:space:]]*"//g'	\
		-e 's/"}$//g'														\
		-e 's/\\n/\n/g'														\
		-e "s/%%SELF_CONTAINER_CUK%%/${K2HR3_SELF_CUK}/g"					\
		-e "s/%%FILE_DOWNLOAD_DATE%%/${K2HR3_DATE}/g"						\
		> "${RESOURCE_TEMP_FILE}" 2>/dev/null

	#
	# Check for updates
	#
	FOUND_DIFFERENCE=0
	if [ -f "${ANTPICKAX_ETC_DIR}/${K2HDDKC_INI_FILE}" ]; then
		#
		# Cut 'DATE' line
		#
		sed -e 's/^DATE[[:space:]]*=.*$//g' -e 's/^[[:space:]]*//g' "${ANTPICKAX_ETC_DIR}/${K2HDDKC_INI_FILE}"	> "${RESOURCE_COMPARE_CUR_FILE}" 2>/dev/null
		sed -e 's/^DATE[[:space:]]*=.*$//g' -e 's/^[[:space:]]*//g' "${RESOURCE_TEMP_FILE}"						> "${RESOURCE_COMPARE_NEW_FILE}" 2>/dev/null

		#
		# Compare without blank lines
		#
		if ! diff -B "${RESOURCE_COMPARE_CUR_FILE}" "${RESOURCE_COMPARE_NEW_FILE}" >/dev/null 2>&1; then
			FOUND_DIFFERENCE=1
		fi

		rm -f "${RESOURCE_COMPARE_CUR_FILE}" "${RESOURCE_COMPARE_NEW_FILE}"
	else
		FOUND_DIFFERENCE=1
	fi

	#
	# Update configuarion file
	#
	if [ "${FOUND_DIFFERENCE}" -eq 1 ]; then
		if ! cp "${RESOURCE_TEMP_FILE}" "${ANTPICKAX_ETC_DIR}/${K2HDDKC_INI_FILE}" 2>/dev/null; then
			rm -f "${RESOURCE_TEMP_FILE}"
			prn_msg "[ERROR] Could not copy resource file to ${ANTPICKAX_ETC_DIR}/${K2HDDKC_INI_FILE}"
			continue;
		fi
		prn_msg "[MESSAGE] Updated ${ANTPICKAX_ETC_DIR}/${K2HDDKC_INI_FILE}"
		FILE_NOT_UPDATED_YET=0
		LOOP_SLEEP_CUR=${LOOP_SLEEP_SHORT}
	else
		prn_msg "[MESSAGE] Nothing to update"
	fi

	rm -f "${RESOURCE_TEMP_FILE}"
done

prn_msg "[MESSAGE] Process terminating..."

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
