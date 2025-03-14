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
#
# This script expects the following environment variables to be
# set. These values are used as elements of CUK data when
# registering to K2HR3 Role members.
#
#	ANTPICKAX_ETC_DIR			configuration firectory
#								(ex. /etc/antpickax)
#	K2HR3_API_URL				k2hr3 api url
#	K2HR3_YRN_PREFIX			Specifies the prefix of the yrn
#								path for k2hr3. It specifies the
#								prefix for "yrn:yahoo:::<namespace>:role:<cluster name>/{server|slave}".
#								If omitted, it will use "yrn:yahoo:::".
#	K2HR3_TENANT				tenant name(=k8s namespace)
#	K2HDKC_DOMAIN				base domain name
#	K2HDKC_CLUSTER_NAME			k2hdkc cluster name
#	K2HDKC_MODE					k2hdkc(chmpx) mode, server or
#								slave
#
#	K2HDKC_NODE_NAME			node name on this container's node
#								(spec.nodeName)
#	K2HDKC_NODE_IP				node host ip address on this
#								container's node(status.hostIP)
#	K2HDKC_POD_NAME				pod name containing this container
#								(metadata.name)
#	K2HDKC_NAMESPACE			pod namespace for this container
#								(metadata.namespace)
#	K2HDKC_POD_SERVICE_ACCOUNT	pod service account for this
#								container(spec.serviceAccountName)
#	K2HDKC_POD_ID				pod id containing this container
#								(metadata.uid)
#	K2HDKC_POD_IP				pod ip address containing this
#								container(status.podIP)
#
#	SEC_CA_MOUNTPOINT			CA certification directory
#	SEC_K2HR3_TOKEN_MOUNTPOINT	K2HR3 unscoped token directory
#	SEC_UTOKEN_FILENAME			K2HR3 unscoped token filename
#	CERT_PERIOD_DAYS			Period days for certificate
#
#----------------------------------------------------------
# Load variables from system file
#
#	K2HDKC_CONTAINER_ID			This value is the <docker id> that
#								this script reads from '/proc/<pid>/cgroups'.
#								(kubernetes uses this 'docker id'
#								as the 'container id'.)
#								This value is added to CUK data.
#
#----------------------------------------------------------
# Output files
#
# This script outputs the following files under '/etc/antpickax'
# directory. These file contents can be used when accessing K2HR3
# REST API.
#
#	K2HR3_FILE_API_URL			k2hr3 api url with path
#	K2HR3_FILE_ROLE				yrn full path to the role
#	K2HR3_FILE_ROLE_TOKEN		symbolic link to role token file
#	K2HR3_FILE_CUK				cuk value for url argument to
#								K2HR3 REST API(PUT/GET/DELETE/etc)
#	K2HR3_FILE_CUKENC			urlencoded cuk value
#	K2HR3_FILE_APIARG			packed cuk argument("extra=...&cuk=value")
#								to K2HR3 REST API(PUT/GET/DELETE/etc)
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
DBAAS_FILE_API_URL="k2hr3-api-url"
DBAAS_FILE_REGISTER_URL="k2hr3-register-url"
DBAAS_FILE_ROLE="k2hr3-role"
DBAAS_FILE_ROLE_TOKEN="k2hr3-role-token"
DBAAS_FILE_RESOURCE="k2hr3-resource"
DBAAS_FILE_CUK="k2hr3-cuk"
DBAAS_FILE_CUKENC="k2hr3-cukencode"
DBAAS_FILE_APIARG="k2hr3-apiarg"

K2HR3_API_REGISTER_PATH="/v1/role"

#
# Variables
#
K2HDKC_CONTAINER_ID=""

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
# Check Environments
#----------------------------------------------------------
if [ -z "${ANTPICKAX_ETC_DIR}" ] || [ ! -d "${ANTPICKAX_ETC_DIR}" ]; then
	echo "[ERROR] ${PRGNAME} : ANTPICKAX_ETC_DIR environment is not set or not directory." 1>&2
	exit 1
fi
if [ -z "${K2HR3_API_URL}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_API_URL environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HR3_YRN_PREFIX}" ]; then
	K2HR3_YRN_PREFIX="yrn:yahoo:::"
fi
if [ -z "${K2HR3_TENANT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_TENANT environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_DOMAIN}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_DOMAIN environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_CLUSTER_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_CLUSTER_NAME environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_MODE}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_MODE environment is not set or wrong value, it must be set \"server\" or \"slave\"." 1>&2
	exit 1
elif [ "${K2HDKC_MODE}" = "SERVER" ] || [ "${K2HDKC_MODE}" = "server" ]; then
	K2HDKC_MODE="server"
elif [ "${K2HDKC_MODE}" = "SLAVE" ] || [ "${K2HDKC_MODE}" = "slave" ]; then
	K2HDKC_MODE="slave"
else
	echo "[ERROR] ${PRGNAME} : K2HDKC_MODE environment is not set or wrong value, it must be set \"server\" or \"slave\"." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_NODE_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_NODE_NAME environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_NODE_IP}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_NODE_IP environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_POD_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_POD_NAME environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_NAMESPACE}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_NAMESPACE environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_POD_SERVICE_ACCOUNT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_POD_SERVICE_ACCOUNT environment is not set." 1>&2
	exit 1
fi
if [ -z "${K2HDKC_POD_ID}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_POD_ID environment is not set." 1>&2
	exit 1
fi
# shellcheck disable=SC2153
if [ -z "${K2HDKC_POD_IP}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HDKC_POD_IP environment is not set." 1>&2
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
if [ -z "${CERT_PERIOD_DAYS}" ]; then
	echo "[ERROR] ${PRGNAME} : CERT_PERIOD_DAYS environment is not set." 1>&2
	exit 1
fi

#----------------------------------------------------------
# Get Scoped token
#----------------------------------------------------------
#
# Request options for curl
#
RESPONSE_FILE="/tmp/${PRGNAME}_response.result"
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

#
# Unscoped token from environment
#
if [ ! -f "${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3 Unscoped token file(${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}) is not existed." 1>&2
	exit 1
fi
K2HR3_UNSCOPED_TOKEN=$(tr -d '\n' < "${SEC_K2HR3_TOKEN_MOUNTPOINT}/${SEC_UTOKEN_FILENAME}")

rm -f "${RESPONSE_FILE}"

#
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<utoken>" -d '{"auth":{"tenantName":"<tenant>"}}' -X POST https://<k2hr3 api>/v1/user/tokens
# [Response]
#	201
#	{"result":true,"message":"succeed","scoped":true,"token":"<token>"}
#
REQUEST_POST_BODY="-d '{\"auth\":{\"tenantName\":\"${K2HR3_TENANT}\"}}'"
REQUEST_HEADERS="-H 'Content-Type: application/json' -H \"x-auth-token:U=${K2HR3_UNSCOPED_TOKEN}\""

if ! REQ_EXIT_CODE=$(/bin/sh -c "${CURL_COMMAND} ${REQOPT_SILENT} ${REQOPT_CACERT} ${REQOPT_EXITCODE} ${REQOPT_OUTPUT} ${REQUEST_HEADERS} ${REQUEST_POST_BODY} -X POST ${K2HR3_API_URL}/v1/user/tokens"); then
	echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with curl error code" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi
if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "201" ]; then
	echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed with http exit code(${REQ_EXIT_CODE})" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi

#
# Check result
#
REQ_RESULT=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*result=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
REQ_MESSAGE=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*message=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
REQ_SCOPED=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*scoped=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
REQ_TOKEN=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*token=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
if [ -z "${REQ_RESULT}" ] || [ -z "${REQ_SCOPED}" ] || [ -z "${REQ_TOKEN}" ] || [ "${REQ_RESULT}" != "true" ] || [ "${REQ_SCOPED}" != "true" ]; then
	echo "[ERROR] ${PRGNAME} : Request(get scoped token) is failed by \"${REQ_MESSAGE}\"" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi
K2HR3_SCOPED_TOKEN="${REQ_TOKEN}"

rm -f "${RESPONSE_FILE}"

#----------------------------------------------------------
# Get Role token
#----------------------------------------------------------
#
# [Request]
#	curl -s -S -w '%{http_code}\n' -o <file> -H 'Content-Type: application/json' -H "x-auth-token:U=<scoped token>" -X GET https://<k2hr3 api>/v1/role/token/<role name>?expire=0
# [Response]
#	200
#	{"result":true,"message":null,"token":"<token>","registerpath":"<....>"}
#
REQUEST_URLARGS="/v1/role/token/${K2HDKC_CLUSTER_NAME}/${K2HDKC_MODE}"
REQUEST_HEADERS="-H 'Content-Type: application/json' -H \"x-auth-token:U=${K2HR3_SCOPED_TOKEN}\""

if ! REQ_EXIT_CODE=$(/bin/sh -c "${CURL_COMMAND} ${REQOPT_SILENT} ${REQOPT_CACERT} ${REQOPT_EXITCODE} ${REQOPT_OUTPUT} ${REQUEST_HEADERS} -X GET ${K2HR3_API_URL}${REQUEST_URLARGS}?expire=0"); then
	echo "[ERROR] ${PRGNAME} : Request(get role token for server) is failed with curl error code" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi
if [ -z "${REQ_EXIT_CODE}" ] || [ "${REQ_EXIT_CODE}" != "200" ]; then
	echo "[ERROR] ${PRGNAME} : Request(get role token for server) is failed with http exit code(${REQ_EXIT_CODE})" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi

REQ_RESULT=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*result=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
REQ_MESSAGE=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*message=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
REQ_TOKEN=$(sed -e 's/:/=/g' -e 's/"//g' -e 's/,/ /g' -e 's/[{|}]//g' -e 's/.*token=[.|^ ]*//g' -e 's/ .*$//g' "${RESPONSE_FILE}")
if [ -z "${REQ_RESULT}" ] || [ -z "${REQ_SCOPED}" ] || [ -z "${REQ_TOKEN}" ] || [ "${REQ_RESULT}" != "true" ] || [ "${REQ_SCOPED}" != "true" ]; then
	echo "[ERROR] ${PRGNAME} : Request(get role token for server) is failed by \"${REQ_MESSAGE}\"" 1>&2
	rm -f "${RESPONSE_FILE}"
	exit 1
fi
K2HR3_ROLE_TOKEN="${REQ_TOKEN}"

rm -f "${RESPONSE_FILE}"

#----------------------------------------------------------
# Create registration parameters
#----------------------------------------------------------
#
# Make CONTAINER_ID with checking pod id
#
# shellcheck disable=SC2010
if ! POC_FILE_NAMES=$(ls -1 /proc/ | grep -E "[0-9]+" 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Could not find any /proc/<process id> directory." 1>&2
	exit 1
fi

CONTAINER_ID_UIDS=""
for local_procid in ${POC_FILE_NAMES}; do
	if [ ! -f /proc/"${local_procid}"/cgroup ]; then
		continue
	fi
	if ! local_all_line=$(cat /proc/"${local_procid}"/cgroup); then
		continue
	fi
	for local_line in ${local_all_line}; do
		if ! CONTAINER_ID_UIDS=$(echo "${local_line}" | sed -e 's#.*pod##g' -e 's#\.slice##g' -e 's#\.scope##g' -e 's#docker-##g' 2>/dev/null); then
			continue
		fi
		if [ -n "${CONTAINER_ID_UIDS}" ]; then
			break
		fi
	done
	if [ -n "${CONTAINER_ID_UIDS}" ]; then
		break
	fi
done

if [ -n "${CONTAINER_ID_UIDS}" ]; then
	K2HDKC_TMP_POD_ID=$(echo "${CONTAINER_ID_UIDS}" | sed -e 's#/# #g' 2>/dev/null | awk '{print $1}' 2>/dev/null)
	K2HDKC_CONTAINER_ID=$(echo "${CONTAINER_ID_UIDS}" | sed -e 's#/# #g' 2>/dev/null | awk '{print $2}' 2>/dev/null)

	if [ -z "${K2HDKC_POD_ID}" ]; then
		K2HDKC_POD_ID=${K2HDKC_TMP_POD_ID}
	else
		if [ -z "${K2HDKC_TMP_POD_ID}" ] || [ "${K2HDKC_POD_ID}" != "${K2HDKC_TMP_POD_ID}" ]; then
			echo "[WARNING] ${PRGNAME} : Specified pod id(${K2HDKC_POD_ID}) is not correct, so that use current pod id(${K2HDKC_TMP_POD_ID}) instead of it." 1>&2
			K2HDKC_POD_ID=${K2HDKC_TMP_POD_ID}
		fi
	fi
fi
if [ -z "${K2HDKC_CONTAINER_ID}" ]; then
	echo "[ERROR] ${PRGNAME} : Could not get container id." 1>&2
	exit 1
fi

#
# Make CUK parameter
#
# The CUK parameter is a base64 url encoded value from following JSON object string(sorted keys by a-z).
#	{
#		"k8s_namespace":		${K2HDKC_NAMESPACE}
#		"k8s_service_account":	${K2HDKC_POD_SERVICE_ACCOUNT}
#		"k8s_node_name":		${K2HDKC_NODE_NAME},
#		"k8s_node_ip":			${K2HDKC_NODE_IP},
#		"k8s_pod_name":			${K2HDKC_POD_NAME},
#		"k8s_pod_id":			${K2HDKC_POD_ID}
#		"k8s_pod_ip":			${K2HDKC_POD_IP}
#		"k8s_container_id":		${K2HDKC_CONTAINER_ID}
#		"k8s_k2hr3_rand":		"random 32 byte value formatted hex string"
#	}
#
# Base64 URL encoding converts the following characters.
#	'+'				to '-'
#	'/'				to '_'
#	'='(end word)	to '%3d'
#
if ! K2HDKC_REG_RAND=$(od -vAn -tx8 -N16 < /dev/urandom 2>/dev/null | tr -d '[:blank:]' 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Could not make 64 bytes random value for CUK value." 1>&2
	exit 1
fi

# shellcheck disable=SC2089
CUK_STRING="{\
\"k8s_container_id\":\"${K2HDKC_CONTAINER_ID}\",\
\"k8s_k2hr3_rand\":\"${K2HDKC_REG_RAND}\",\
\"k8s_namespace\":\"${K2HDKC_NAMESPACE}\",\
\"k8s_node_ip\":\"${K2HDKC_NODE_IP}\",\
\"k8s_node_name\":\"${K2HDKC_NODE_NAME}\",\
\"k8s_pod_id\":\"${K2HDKC_POD_ID}\",\
\"k8s_pod_ip\":\"${K2HDKC_POD_IP}\",\
\"k8s_pod_name\":\"${K2HDKC_POD_NAME}\",\
\"k8s_service_account\":\"${K2HDKC_POD_SERVICE_ACCOUNT}\"\
}"

if ! CUK_BASE64_STRING=$(echo "${CUK_STRING}" 2>/dev/null | tr -d '\n' | sed -e 's/ //g' 2>/dev/null | base64 2>/dev/null | tr -d '\n' 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Could not make base64 string for CUK value." 1>&2
	exit 1
fi
if ! CUK_BASE64_URLENC=$(echo "${CUK_BASE64_STRING}" 2>/dev/null | tr -d '\n' | sed -e 's/+/-/g' -e 's#/#_#g' -e 's/=/%3d/g' 2>/dev/null); then
	echo "[ERROR] ${PRGNAME} : Could not make base64 url encode string for CUK value." 1>&2
	exit 1
fi

#
# Make EXTRA parameter
#
# Currently, the value of "extra" is "k8s-auto-v1" only.
#
EXTRA_STRING='k8s-auto-v1'

#
# Make 'tag' paraemter which is used CUSTOM_ID_SEED value in k2hdkc configuration
#
TAG_STRING=${K2HDKC_POD_NAME}

#
# Make K2HR3 YRN for role and resource
#
K2HDKC_ROLE_YRN=${K2HR3_YRN_PREFIX}${K2HDKC_NAMESPACE}:role:${K2HDKC_CLUSTER_NAME}/${K2HDKC_MODE}
K2HDKC_RESOURCE_YRN=${K2HR3_YRN_PREFIX}${K2HDKC_NAMESPACE}:resource:${K2HDKC_CLUSTER_NAME}/${K2HDKC_MODE}

#----------------------------------------------------------
# Save parameters for accessing to K2HR3
#----------------------------------------------------------
#
# Make each parameters to files
#
echo "${K2HR3_API_URL}"													| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_API_URL}"
echo "${K2HR3_API_URL}${K2HR3_API_REGISTER_PATH}"						| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_REGISTER_URL}"
echo "${K2HDKC_ROLE_YRN}"												| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_ROLE}"
echo "${K2HDKC_RESOURCE_YRN}"											| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_RESOURCE}"
echo "${CUK_BASE64_STRING}"												| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_CUK}"
echo "${CUK_BASE64_URLENC}"												| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_CUKENC}"
echo "extra=${EXTRA_STRING}&cuk=${CUK_BASE64_URLENC}&tag=${TAG_STRING}"	| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_APIARG}"
echo "${K2HR3_ROLE_TOKEN}"												| tr -d '\n' > "${ANTPICKAX_ETC_DIR}/${DBAAS_FILE_ROLE_TOKEN}"

#----------------------------------------------------------
# Create certificate and Save those
#----------------------------------------------------------
if [ -n "${SEC_CA_MOUNTPOINT}" ]; then
	#
	# Create certificate for me
	#
	if ! /bin/sh "${SRCTOP}/dbaas-setup-certificate.sh" "${ANTPICKAX_ETC_DIR}" "${SEC_CA_MOUNTPOINT}" "${CERT_PERIOD_DAYS}"; then
		echo "[ERROR] ${PRGNAME} : Failed to creating certificate." 1>&2
		exit 1
	fi
fi

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
echo "[Succeed] ${PRGNAME} : Finished variables setup without any error." 1>&2
exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
