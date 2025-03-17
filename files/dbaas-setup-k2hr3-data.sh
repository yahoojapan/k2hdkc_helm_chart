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
#	ANTPICKAX_ETC_DIR			ex. /etc/antpickax
#	K2HR3_API_URL				ex. https://<k2hr3 api host>:<port=443>
#	K2HR3_TENANT				ex. default
#	SEC_CA_MOUNTPOINT			ex. /secret-ca
#	SEC_K2HR3_TOKEN_MOUNTPOINT	ex. /secret-k2hr3-token
#	SEC_UTOKEN_FILENAME			ex. unscopedToken
#	K2HDKC_CLUSTER_NAME			ex. mydbaas
#	K2HDKC_SVR_PORT				ex. 8020
#	K2HDKC_SVR_CTLPORT			ex. 8021
#	K2HDKC_SLV_CTLPORT			ex. 8022
#	K2HDKC_INI_TEMPL_FILE		ex. /configmap/dbaas-k2hdkc.ini.templ
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
if [ -z "${ANTPICKAX_ETC_DIR}" ] || [ ! -d "${ANTPICKAX_ETC_DIR}" ]; then
	if ! mkdir -p "${ANTPICKAX_ETC_DIR}"; then
		echo "[ERROR] ${PRGNAME} : ANTPICKAX_ETC_DIR environment is not set or could not create it." 1>&2
		exit 1
	fi
fi
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

if [ -z "${K2HDKC_SVR_PORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_SVR_PORT environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_SVR_CTLPORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_SVR_CTLPORT environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_SLV_CTLPORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_SLV_CTLPORT environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_INI_TEMPL_FILE}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_INI_TEMPL_FILE environment is not set." 1>&2
	exit 1
fi

#
# Temporary files
#
K2HDKC_INI_EXPAND_FILE="/tmp/${PRGNAME}_k2hdkc.ini"
RESOURCE_BODY_FILE="/tmp/${PRGNAME}_resource.body"
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
	if echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl." 1>&2
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		setup_apt_envirnment
		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl." 1>&2
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 || ! dnf install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl." 1>&2
			exit 1
		fi
	else
		echo "[ERROR] Unknown OS type(${OS_NAME})." 1>&2
		exit 1
	fi
fi
CURL_COMMAND=$(command -v curl | tr -d '\n')

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
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with curl error code" 1>&2
		rm -f "${RESPONSE_FILE}"
		return 1
	fi
	if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "201" ]; then
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with http exit code(${REQ_EXIT_CODE})" 1>&2
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	REQ_RESULT=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*result=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_MESSAGE=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*message=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_SCOPED=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*scoped=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	REQ_TOKEN=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*token=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	if [ -z "${REQ_RESULT}" ] || [ -z "${REQ_SCOPED}" ] || [ -z "${REQ_TOKEN}" ] || [ "${REQ_RESULT}" != "true" ] || [ "${REQ_SCOPED}" != "true" ]; then
		echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed by \"${REQ_MESSAGE}\"" 1>&2
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	K2HR3_SCOPED_TOKEN="${REQ_TOKEN}"

	rm -f "${RESPONSE_FILE}"
	return 0
}

#----------------------------------------------------------
# Post request utility
#----------------------------------------------------------
# [Input]
#	$1		url path(ex. /v1/role)
#	$2		body type("STRING" or "FILE")
#	$3		post body string or file path
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
raw_post_request()
{
	REQUERST_URL_PATH="$1"
	if [ -n "$2" ] && [ "$2" = "FILE" ]; then
		REQUEST_POST_BODY="--data-binary @$3"
	else
		REQUEST_POST_BODY="-d '$3'"
	fi
	REQUEST_HEADERS="-H 'Content-Type: application/json' -H \"x-auth-token:U=${K2HR3_SCOPED_TOKEN}\""

	rm -f "${RESPONSE_FILE}"

	if ! REQ_EXIT_CODE=$(/bin/sh -c "${CURL_COMMAND} ${REQOPT_SILENT} ${REQOPT_CACERT} ${REQOPT_EXITCODE} ${REQOPT_OUTPUT} ${REQUEST_HEADERS} ${REQUEST_POST_BODY} -X POST ${K2HR3_API_URL}${REQUERST_URL_PATH}"); then
		echo "[ERROR] ${PRGNAME} : Post request(${REQUERST_URL_PATH}, \"$2\") is failed with curl error code" 1>&2
		rm -f "${RESPONSE_FILE}"
		return 1
	fi
	if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "201" ]; then
		echo "[ERROR] ${PRGNAME} : Post request(${REQUERST_URL_PATH}, \"$2\") is failed with http exit code(${REQ_EXIT_CODE})" 1>&2
		rm -f "${RESPONSE_FILE}"
		return 1
	fi

	RESPONSE_RESULT=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*result=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	RESPONSE_MESSAGE=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*message=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
	if [ -z "${RESPONSE_RESULT}" ] || [ "${RESPONSE_RESULT}" != "true" ]; then
		echo "[ERROR] ${PRGNAME} : Post request(${REQUERST_URL_PATH}, \"$2\") is failed by \"${RESPONSE_MESSAGE}\"" 1>&2
		rm -f "${RESPONSE_FILE}"
		exit 1
	fi

	rm -f "${RESPONSE_FILE}"
	return 0
}

#----------------------------------------------------------
# Create INI file(expand from template)
#----------------------------------------------------------
# [Input]
#	$1		input file path
#	$1		output file path
#
# [Using global variables]
#	SEC_CA_MOUNTPOINT
#	ANTPICKAX_ETC_DIR
#	K2HR3_TENANT
#	K2HDKC_CLUSTER_NAME
#
# Result:	$?
#
expanded_ini_file()
{
	INPUT_INI_FILE="$1"
	OUTPUT_INI_FILE="$2"

	if [ -n "${SEC_CA_MOUNTPOINT}" ]; then
		INIPART_SSL="SSL = on"
		INIPART_SSL_VERIFY_PEER="SSL_VERIFY_PEER = on"
		INIPART_CAPATH="CAPATH = ${ANTPICKAX_ETC_DIR}/ca.crt"
		INIPART_SERVER_CERT="SERVER_CERT = ${ANTPICKAX_ETC_DIR}/server.crt"
		INIPART_SERVER_PRIKEY="SERVER_PRIKEY = ${ANTPICKAX_ETC_DIR}/server.key"
		INIPART_SLAVE_CERT="SLAVE_CERT = ${ANTPICKAX_ETC_DIR}/client.crt"
		INIPART_SLAVE_PRIKEY="SLAVE_PRIKEY = ${ANTPICKAX_ETC_DIR}/client.key"
	else
		INIPART_SSL="SSL = no"
		INIPART_SSL_VERIFY_PEER=""
		INIPART_CAPATH=""
		INIPART_SERVER_CERT=""
		INIPART_SERVER_PRIKEY=""
		INIPART_SLAVE_CERT=""
		INIPART_SLAVE_PRIKEY=""
	fi
	INI_SSL_SETTING="${INIPART_SSL}\\n${INIPART_SSL_VERIFY_PEER}\\n${INIPART_CAPATH}\\n${INIPART_SERVER_CERT}\\n${INIPART_SERVER_PRIKEY}\\n${INIPART_SLAVE_CERT}\\n${INIPART_SLAVE_PRIKEY}"

	if ! sed -e "s#%%K2HR3_TENANT_NAME%%#${K2HR3_TENANT}#g"					\
			-e "s#%%K2HDKC_DBAAS_CLUSTER_NAME%%#${K2HDKC_CLUSTER_NAME}#g"	\
			-e "s#%%CHMPX_SSL_SETTING%%#${INI_SSL_SETTING}#g"				\
			"${INPUT_INI_FILE}"												\
			> "${OUTPUT_INI_FILE}"; then

		echo "[ERROR] ${PRGNAME} : Failed expand ini file from ${INPUT_INI_FILE} to ${OUTPUT_INI_FILE}" 1>&2
		rm -f "${OUTPUT_INI_FILE}"
		return 1
	fi

	return 0
}

#----------------------------------------------------------
# Get scoped token for tenant
#----------------------------------------------------------
if [ ! -f "${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3 Unscoped token file(${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}) is not existed." 1>&2
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
# Expand INI file
#----------------------------------------------------------
if ! expanded_ini_file "${K2HDKC_INI_TEMPL_FILE}" "${K2HDKC_INI_EXPAND_FILE}"; then
	exit 1
fi
if [ ! -f "${K2HDKC_INI_EXPAND_FILE}" ]; then
	exit 1
fi

#----------------------------------------------------------
# Set RESOURCE(main)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -d '.....' -X POST https://<k2hr3 api>/v1/resource
#	body = {
#			"resource": {
#				"name": <cluster name>,
#				"type": "string",
#				"data": <ini file>,
#				"keys": {
#					foo: bar,
#				}
#			}
#		}
#
# [Response]
#	201
#	{"result":true,"message":"succeed"}
#
RESOURCE_MAIN_KEYS="{\"cluster-name\":\"${K2HDKC_CLUSTER_NAME}\",\"chmpx-server-port\":${K2HDKC_SVR_PORT},\"chmpx-server-ctlport\":${K2HDKC_SVR_CTLPORT},\"chmpx-slave-ctlport\":${K2HDKC_SLV_CTLPORT}}"
RESOURCE_MAIN_DATA=$(sed -e ':loop; N; $!b loop; s/\n/\\n/g' -e 's/"/\\"/g' "${K2HDKC_INI_EXPAND_FILE}")
RESOURCE_MAIN_ALL="{\"resource\":{\"name\":\"${K2HDKC_CLUSTER_NAME}\",\"type\":\"string\",\"data\":\"${RESOURCE_MAIN_DATA}\",\"keys\":${RESOURCE_MAIN_KEYS}}}"
echo "${RESOURCE_MAIN_ALL}" > "${RESOURCE_BODY_FILE}"

if ! raw_post_request "/v1/resource" "FILE" "${RESOURCE_BODY_FILE}"; then
	rm -f "${K2HDKC_INI_EXPAND_FILE}"
	rm -f "${RESOURCE_BODY_FILE}"
	exit 1
fi
rm -f "${K2HDKC_INI_EXPAND_FILE}"
rm -f "${RESOURCE_BODY_FILE}"

#----------------------------------------------------------
# Set RESOURCE(server/slave)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -d '.....' -X POST https://<k2hr3 api>/v1/resource
#	body = {
#			"resource": {
#				"name": <cluster name/(server|slave)>,
#				"type": "string",
#				"data": "",
#				"keys": {
#					"chmpx-mode": "SERVER|SLAVE",
#				}
#			}
#		}
#
# [Response]
#	201
#	{"result":true,"message":"succeed"}
#
RESOURCE_SERVER_ALL="{\"resource\":{\"name\":\"${K2HDKC_CLUSTER_NAME}/server\",\"type\":\"string\",\"data\":\"\",\"keys\":{\"chmpx-mode\":\"SERVER\"}}}"
RESOURCE_SLAVE_ALL="{\"resource\":{\"name\":\"${K2HDKC_CLUSTER_NAME}/slave\",\"type\":\"string\",\"data\":\"\",\"keys\":{\"chmpx-mode\":\"SLAVE\"}}}"

#
# resource for server
#
if ! raw_post_request "/v1/resource" "STRING" "${RESOURCE_SERVER_ALL}"; then
	exit 1
fi

#
# resource for slave
#
if ! raw_post_request "/v1/resource" "STRING" "${RESOURCE_SLAVE_ALL}"; then
	exit 1
fi

#----------------------------------------------------------
# Set POLICY
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -d '.....' -X POST https://<k2hr3 api>/v1/policy
#	body = {
#			policy:	{
#				name:		<cluster name>
#				effect:		allow
#				action:		["yrn:yahoo::::action:read"]
#				resource:  [
#					"yrn:yahoo:::<tenant>:resource:<cluster name>/server",
#					"yrn:yahoo:::<tenant>:resource:<cluster name>/slave"
#				]
#			}
#		}
#
# [Response]
#	201
#	{"result":true,"message":"succeed"}
#
POLICY_ALL="{\"policy\":{\"name\":\"${K2HDKC_CLUSTER_NAME}\",\"effect\":\"allow\",\"action\":[\"yrn:yahoo::::action:read\"],\"resource\":[\"yrn:yahoo:::${K2HR3_TENANT}:resource:${K2HDKC_CLUSTER_NAME}/server\",\"yrn:yahoo:::${K2HR3_TENANT}:resource:${K2HDKC_CLUSTER_NAME}/slave\"]}}"

if ! raw_post_request "/v1/policy" "STRING" "${POLICY_ALL}"; then
	exit 1
fi

#----------------------------------------------------------
# Set ROLE(main)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -d '.....' -X POST https://<k2hr3 api>/v1/role
#	body = {
#		"role":	{
#			"name":	<cluster name>,
#			"policies": [
#				"yrn:yahoo:::<tenant>:policy:<cluster name>"
#			]
#		}
#	}
#
# [Response]
#	201
#	{"result":true,"message":"succeed"}
#
ROLE_ALL="{\"role\":{\"name\":\"${K2HDKC_CLUSTER_NAME}\",\"policies\":[\"yrn:yahoo:::${K2HR3_TENANT}:policy:${K2HDKC_CLUSTER_NAME}\"]}}"

if ! raw_post_request "/v1/role" "STRING" "${ROLE_ALL}"; then
	exit 1
fi

#----------------------------------------------------------
# Set ROLE(server/slave)
#----------------------------------------------------------
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<token>" -d '.....' -X POST https://<k2hr3 api>/v1/role
#	body = {
#		"role":	{
#			"name":	<cluster name>/<server|slave>,
#		}
#	}
#
# [Response]
#	201
#	{"result":true,"message":"succeed"}
#
ROLE_SERVER_ALL="{\"role\":{\"name\":\"${K2HDKC_CLUSTER_NAME}/server\"}}"
ROLE_SLAVE_ALL="{\"role\":{\"name\":\"${K2HDKC_CLUSTER_NAME}/slave\"}}"

#
# for for server
#
if ! raw_post_request "/v1/role" "STRING" "${ROLE_SERVER_ALL}"; then
	exit 1
fi

#
# for for slave
#
if ! raw_post_request "/v1/role" "STRING" "${ROLE_SLAVE_ALL}"; then
	exit 1
fi

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
echo "[SUCCEED] ${PRGNAME} : Create K2HR3 Resource/Policy/Role for ${K2HDKC_CLUSTER_NAME}" 1>&2
exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
