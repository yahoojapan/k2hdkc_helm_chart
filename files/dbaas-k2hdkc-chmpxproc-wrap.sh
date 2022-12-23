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
# Common variables
#----------------------------------------------------------
#PRGNAME=$(basename "$0")
#SCRIPTDIR=$(dirname "$0")
#SCRIPTDIR=$(cd "${SRCTOP}" || exit 1; pwd)

ANTPICKAX_ETC_DIR="/etc/antpickax"
K2HR3_FILE_RESOURCE="k2hr3-resource"

RETRYCOUNT=30
SLEEP_SHORT=10

#----------------------------------------------------------
# Make configuration file path
#----------------------------------------------------------
K2HR3_YRN_RESOURCE=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" 2>/dev/null)
CHMPX_MODE=$(echo "${K2HR3_YRN_RESOURCE}" | sed 's#[:/]# #g' | awk '{print $NF}')
INI_FILE="${CHMPX_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

if [ -f "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" ]; then
	K2HR3_YRN_RESOURCE=$(tr -d '\n' < "${ANTPICKAX_ETC_DIR}/${K2HR3_FILE_RESOURCE}" 2>/dev/null)
	CHMPX_MODE=$(echo "${K2HR3_YRN_RESOURCE}" | sed 's#[:/]# #g' | awk '{print $NF}')
else
	if [ -z "$1" ]; then
		CHMPX_MODE="server"
	elif [ "$1" = "SERVER" ] || [ "$1" = "server" ]; then
		CHMPX_MODE="server"
	elif [ "$1" = "SLAVE" ] || [ "$1" = "slave" ]; then
		CHMPX_MODE="slave"
	else
		CHMPX_MODE="server"
	fi
fi

INI_FILE="${CHMPX_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
#
# Wait for creating configuarion file
#
FILE_EXISTS=0
while [ "${FILE_EXISTS}" -eq 0 ]; do
	if [ -f "${INI_FILE_PATH}" ]; then
		FILE_EXISTS=1
	else
		RETRYCOUNT=$((RETRYCOUNT - 1))
		if [ "${RETRYCOUNT}" -le 0 ]; then
			echo "[ERROR] ${INI_FILE_PATH} is not existed."
			exit 1
		fi
		sleep "${SLEEP_SHORT}"
	fi
done

#
# Run chmpx process
#
set -e

#
# stdio/stderr is not redirected.
#
chmpx -conf "${INI_FILE_PATH}" -d err

exit $?

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
