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
# Environments
#----------------------------------------------------------
# This script uses following environments
#
#	K2HR3_API_URL				ex. https://<k2hr3 api host>:<port=443>
#	K2HR3_TENANT				ex. default
#	SEC_CA_MOUNTPOINT			ex. /secret-ca
#	SEC_K2HR3_TOKEN_MOUNTPOINT	ex. /secret-k2hr3-token
#	SEC_UTOKEN_FILENAME			ex. unscopedToken
#	K2HDKC_CLUSTER_NAME			ex. mydbaas
#

#----------------------------------------------------------
# Common Variables
#----------------------------------------------------------
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#
# Check environments
#
if [ -z "${K2HR3_API_URL}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_API_URL environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HR3_TENANT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_TENANT environment is not set." 1>&2
	exit 1
fi
if [ -z "${SEC_CA_MOUNTPOINT}" ] || [ ! -d "${SEC_CA_MOUNTPOINT}" ]; then
	echo "[ERROR] ${PRGNAME} : SEC_CA_MOUNTPOINT environment is not set or not directory." 1>&2
	exit 1
fi
if [ -z "${SEC_K2HR3_TOKEN_MOUNTPOINT}" ] || [ ! -d "${SEC_K2HR3_TOKEN_MOUNTPOINT}" ]; then
	echo "[ERROR] ${PRGNAME} : SEC_K2HR3_TOKEN_MOUNTPOINT environment is not set or not directory." 1>&2
	exit 1
fi
if [ -z "${SEC_UTOKEN_FILENAME}" ]; then
	echo "[ERROR] ${PRGNAME} : SEC_UTOKEN_FILENAME environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_CLUSTER_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_CLUSTER_NAME environment is not set." 1>&2
	exit 1
fi

#
# Temporary files
#
RESPONSE_FILE="/tmp/${PRGNAME}_response.result"

#
# Request options for curl
#
REQOPT_SILENT="-s -S"
REQOPT_EXITCODE="-w '%{http_code}\n'"
REQOPT_OUTPUT="-o ${RESPONSE_FILE}"

#
# Request options for CA certificate
#
REQOPT_CACERT=""
if [ -n "${SEC_CA_MOUNTPOINT}" ] && [ -d "${SEC_CA_MOUNTPOINT}" ]; then
	CA_CERT_FILE=$(find "${SEC_CA_MOUNTPOINT}/" -name '*_CA.crt' | head -1)
	if [ -n "${CA_CERT_FILE}" ]; then
		REQOPT_CACERT="--cacert ${CA_CERT_FILE}"
	fi
fi

#----------------------------------------------------------
# Check curl command
#----------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
	CURL_COMMAND=$(command -v curl | tr -d '\n')
else
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
	CURL_COMMAND=$(command -v curl | tr -d '\n')
fi

#----------------------------------------------------------
# Scoped token
#----------------------------------------------------------
# [Input]
#	$1		unscoped token
#	$2		tenant name
#
# [Using global variables]
#	REQOPT_SILENT
#	REQOPT_CACERT
#	REQOPT_EXITCODE
#	REQOPT_OUTPUT
#	RESPONSE_FILE
#
# Result:	$?
#			K2HR3_SCOPED_TOKEN
#
get_k2hr3_scoped_token()
{
	_K2HR3_UNSCOPED_TOKEN="$1"
	_K2HR3_TENANT_NAME="$2"

	REQUEST_POST_BODY="-d '{\"auth\":{\"tenantName\":\"${_K2HR3_TENANT_NAME}\"}}'"
	REQUEST_HEADERS="-H 'Content-Type: application/json' -H \"x-auth-token:U=${_K2HR3_UNSCOPED_TOKEN}\""

	rm -f "${RESPONSE_FILE}"

	#
	# [Request]
	#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<utoken>" -d '{"auth":{"tenantName":"<tenant>"}}' -X POST https://<k2hr3 api>/v1/user/tokens
	# [Response]
	#	201
	#	{"result":true,"message":"succeed","scoped":true,"token":"<token>"}
	#
	if ! REQ_EXIT_CODE=$(/bin/sh -c "${CURL_COMMAND} ${REQOPT_SILENT} ${REQOPT_CACERT} ${REQOPT_EXITCODE} ${REQOPT_OUTPUT} ${REQUEST_HEADERS} ${REQUEST_POST_BODY} -X POST ${K2HR3_API_URL}/v1/user/tokens"); then
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with curl error code"
		rm -f "${RESPONSE_FILE}"
		return 1
	fi
	if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "201" ]; then
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with http exit code(${REQ_EXIT_CODE})"
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	REQ_RESULT=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*result=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_MESSAGE=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*message=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_SCOPED=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*scoped=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_TOKEN=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*token=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	if [ -z "${REQ_RESULT}" ] || [ -z "${REQ_SCOPED}" ] || [ -z "${REQ_TOKEN}" ] || [ "${REQ_RESULT}" != "true" ] || [ "${REQ_SCOPED}" != "true" ]; then
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed by \"${REQ_MESSAGE}\""
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	K2HR3_SCOPED_TOKEN="${REQ_TOKEN}"

	rm -f "${RESPONSE_FILE}"
	return 0
}

#----------------------------------------------------------
# Delete request utility
#----------------------------------------------------------
# [Input]
#	$1		url path(ex. /v1/role)
#
# [Using global variables]
#	REQOPT_SILENT
#	REQOPT_CACERT
#	REQOPT_EXITCODE
#	REQOPT_OUTPUT
#	RESPONSE_FILE
#	K2HR3_API_URL
#	K2HR3_SCOPED_TOKEN
#
# Result:	$?
#
raw_delete_request()
{
	REQUERST_URL_PATH="$1"
	REQUEST_HEADERS="-H 'Content-Type: application/json' -H \"x-auth-token:U=${K2HR3_SCOPED_TOKEN}\""

	rm -f "${RESPONSE_FILE}"

	if ! REQ_EXIT_CODE=$(/bin/sh -c "${CURL_COMMAND} ${REQOPT_SILENT} ${REQOPT_CACERT} ${REQOPT_EXITCODE} ${REQOPT_OUTPUT} ${REQUEST_HEADERS} ${REQUEST_POST_BODY} -X DELETE ${K2HR3_API_URL}${REQUERST_URL_PATH}"); then
		echo "[ERROR] ${PRGNAME} : Delete request(${REQUERST_URL_PATH}) is failed with curl error code"
		rm -f "${RESPONSE_FILE}"
		return 1
	fi
	if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "204" ]; then
		echo "[ERROR] ${PRGNAME} : Delete request(${REQUERST_URL_PATH}) is failed with http exit code(${REQ_EXIT_CODE})"
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	rm -f "${RESPONSE_FILE}"
	return 0
}

#----------------------------------------------------------
# Get scoped token for tenant
#----------------------------------------------------------
if [ ! -f "${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3 Unscoped token file(${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}) is not existed."
	exit 1
fi
K2HR3_UNSCOPED_TOKEN=$(tr -d '\n' < "${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}")

if ! get_k2hr3_scoped_token "${K2HR3_UNSCOPED_TOKEN}" "${K2HR3_TENANT}"; then
	exit 1
fi
if [ -z "${K2HR3_SCOPED_TOKEN}" ]; then
	exit 1
fi

#----------------------------------------------------------
# Variable for result
#----------------------------------------------------------
IS_FAIL_DELETE=0

#----------------------------------------------------------
# DELETE ROLE(main/server/slave)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -X DELETE https://<k2hr3 api>/v1/role
#
# [Response]
#	204
#
IS_SAFE_REMOVE_MAIN=1

#
# role for server
#
if ! raw_delete_request "/v1/role/${K2HDKC_CLUSTER_NAME}/server"; then
	echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME}/server role, but continue..."
	IS_SAFE_REMOVE_MAIN=0
	IS_FAIL_DELETE=1
fi

#
# role for slave
#
if ! raw_delete_request "/v1/role/${K2HDKC_CLUSTER_NAME}/slave"; then
	echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME}/server role, but continue..."
	IS_SAFE_REMOVE_MAIN=0
	IS_FAIL_DELETE=1
fi

#
# role for main
#
if [ "${IS_SAFE_REMOVE_MAIN}" -eq 1 ]; then
	if ! raw_delete_request "/v1/role/${K2HDKC_CLUSTER_NAME}"; then
		echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME} role, but continue..."
		IS_FAIL_DELETE=1
	fi
else
	echo "[WARNING] ${PRGNAME} : Did not delete ${K2HDKC_CLUSTER_NAME} role, because server or slave role was not deleted."
fi

#----------------------------------------------------------
# Delete POLICY
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -X DELETE https://<k2hr3 api>/v1/policy
#
# [Response]
#	204
#
if ! raw_delete_request "/v1/policy/${K2HDKC_CLUSTER_NAME}"; then
	echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME} policy, but continue..."
	IS_FAIL_DELETE=1
fi

#----------------------------------------------------------
# Delete RESOURCE(main/server/slave)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -X DELETE https://<k2hr3 api>/v1/resource
#
# [Response]
#	204
#
IS_SAFE_REMOVE_MAIN=1

#
# resource for server
#
if ! raw_delete_request "/v1/resource/${K2HDKC_CLUSTER_NAME}/server"; then
	echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME}/server resource, but continue..."
	IS_SAFE_REMOVE_MAIN=0
	IS_FAIL_DELETE=1
fi

#
# resource for slave
#
if ! raw_delete_request "/v1/resource/${K2HDKC_CLUSTER_NAME}/slave"; then
	echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME}/slave resource, but continue..."
	IS_SAFE_REMOVE_MAIN=0
	IS_FAIL_DELETE=1
fi

#
# resource for main
#
if [ "${IS_SAFE_REMOVE_MAIN}" -eq 1 ]; then
	if ! raw_delete_request "/v1/resource/${K2HDKC_CLUSTER_NAME}"; then
		echo "[WARNING] ${PRGNAME} : Failed deleting ${K2HDKC_CLUSTER_NAME} resource, but continue..."
		IS_FAIL_DELETE=1
	fi
else
	echo "[WARNING] ${PRGNAME} : Did not delete ${K2HDKC_CLUSTER_NAME} resource, because server or slave role was not deleted."
fi

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
if [ "${IS_FAIL_DELETE}" -ne 0 ]; then
	echo "[FAILED] ${PRGNAME} : Failed deleting some K2HR3 Resource/Policy/Role for ${K2HDKC_CLUSTER_NAME}"
	exit 1
fi

echo "[SUCCEED] ${PRGNAME} : Delete all K2HR3 Resource/Policy/Role for ${K2HDKC_CLUSTER_NAME}"
exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
