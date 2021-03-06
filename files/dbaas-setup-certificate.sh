#!/bin/sh
#
# K2HDKC DBaaS Helm Chart
#
# Copyright 2022 Yahoo! Japan Corporation.
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
# Usage: script <output dir> <CA certs dir> <period days>
# 
# Specify the name of the service that has the ClusterIP,
# such as NodePort.
# Get the IP address from the environment variable using
# the specified service name.
# The obtained IP address will be used as the IP address
# of the SAN of the certificate.
#
#----------------------------------------------------------
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Parse parameter
#----------------------------------------------------------
#
# 1'st parameter is output directory path(ex. /etc/antpickax).
#
if [ $# -lt 1 ]; then
	echo "[ERROR] First paranmeter for output directory path is needed."
	exit 1
fi
if [ ! -d "$1" ]; then
	echo "[ERROR] First paranmeter for output directory path is not directory."
	exit 1
fi
OUTPUT_DIR="$1"
shift

#
# 2'nd parameter is directory path(ex. /secret-ca) for CA certificate.
#
if [ $# -lt 1 ]; then
	echo "[ERROR] Second paranmeter for CA certificate directory path is needed."
	exit 1
fi
if [ ! -d "$1" ]; then
	echo "[ERROR] Second paranmeter for CA certificate directory path is not directory."
	exit 1
fi
CA_CERT_DIR="$1"
shift

#
# 3'rd parameter is period days for certificate(ex. 3650).
#
if [ $# -lt 1 ]; then
	echo "[ERROR] Third paranmeter for period days is not specified."
	exit 1
fi
# shellcheck disable=SC2003
expr "$1" + 1 >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "[ERROR] Third paranmeter for period days is not number."
	exit 1
fi
CERT_PERIOD_DAYS="$1"
shift

#----------------------------------------------------------
# Variables
#----------------------------------------------------------
#
# Hostnames / IP addresses
#
# LOCAL_DOMAIN			ex. default.svc.cluster.local
# LOCAL_HOST_DOMAIN		ex. svc.default.svc.cluster.local
# FULL_HOST_NAME		ex. pod.svc.default.svc.cluster.local
# SHORT_HOST_NAME		ex. pod
# NODOMAIN_HOST_NAME	ex. pod.svc
#
LOCAL_DOMAIN="${CHMPX_POD_NAMESPACE}.${CHMPX_DEFAULT_DOMAIN}"
LOCAL_HOST_DOMAIN=$(hostname -d)
LOCAL_HOST_IP=$(hostname -i)
FULL_HOST_NAME=$(hostname -f)
SHORT_HOST_NAME=$(hostname -s)
NODOMAIN_HOST_NAME=$(echo "${FULL_HOST_NAME}" | sed -e "s/\.${LOCAL_DOMAIN}//g")

#
# Certificate directories / files
#
CERT_WORK_DIR="${OUTPUT_DIR}/certwork"

if [ ! -d "${CERT_WORK_DIR}" ]; then
	mkdir -p "${CERT_WORK_DIR}"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}"
		exit 1
	fi
	mkdir -p "${CERT_WORK_DIR}/private"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/private"
		exit 1
	fi
	mkdir -p "${CERT_WORK_DIR}/newcerts"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/newcerts"
		exit 1
	fi
	mkdir -p "${CERT_WORK_DIR}/oldcerts"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/oldcerts"
		exit 1
	fi
	date +%s > "${CERT_WORK_DIR}/serial"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create file ${CERT_WORK_DIR}/serial"
		exit 1
	fi
	touch "${CERT_WORK_DIR}/index.txt"
	if [ $? -ne 0 ]; then
		echo "[ERROR] Could not create file ${CERT_WORK_DIR}/index.txt"
		exit 1
	fi
fi

#
# Configration files for openssl
#
ORG_OPENSSL_CNF="/etc/ssl/openssl.cnf"
CUSTOM_OPENSSL_CNF="${CERT_WORK_DIR}/openssl.cnf"

SUBJ_CSR_C="JP"
SUBJ_CSR_S="Tokyo"
SUBJ_CSR_O="AntPickax"

#
# CA certificate / private key files
#
# ORG_CA_CERT_FILE	CA certification(ex. default.svc.cluster.local_CA.crt)
# ORG_CA_KEY_FILE	CA private key(ex. default.svc.cluster.local_CA.key)
#
ORG_CA_CERT_FILE=$(find "${CA_CERT_DIR}/" -name '*_CA.crt' | head -1)
ORG_CA_KEY_FILE=$(find "${CA_CERT_DIR}/" -name '*_CA.key' | head -1)
if [ "X${ORG_CA_CERT_FILE}" = "X" ] || [ "X${ORG_CA_KEY_FILE}" = "X" ]; then
	echo "[ERROR] CA certificate file or private key file are not existed."
	exit 1
fi
cp -p "${ORG_CA_CERT_FILE}" "${CERT_WORK_DIR}/cacert.pem"
cp -p "${ORG_CA_KEY_FILE}"  "${CERT_WORK_DIR}/private/cakey.pem"
chmod 0400 "${CERT_WORK_DIR}/private/cakey.pem"

#
# Certificate and private files
#
RAW_CERT_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.crt"
RAW_CSR_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.csr"
RAW_KEY_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.key"

CA_CERT_FILE="${OUTPUT_DIR}/ca.crt"
SERVER_CERT_FILE="${OUTPUT_DIR}/server.crt"
SERVER_KEY_FILE="${OUTPUT_DIR}/server.key"
CLIENT_CERT_FILE="${OUTPUT_DIR}/client.crt"
CLIENT_KEY_FILE="${OUTPUT_DIR}/client.key"

#
# Others
#
LOG_FILE="${CERT_WORK_DIR}/${PRGNAME}.log"

#----------------------------------------------------------
# Check openssl command
#----------------------------------------------------------
OPENSSL_COMMAND=$(command -v openssl | tr -d '\n')
if [ $? -ne 0 ] || [ -z "${OPENSSL_COMMAND}" ]; then
	APK_COMMAND=$(command -v apk | tr -d '\n')
	if [ $? -ne 0 ] || [ -z "${APK_COMMAND}" ]; then
		echo "[ERROR] This container it not ALPINE, It does not support installations other than ALPINE, so exit."
		exit 1
	fi
	${APK_COMMAND} add -q --no-progress --no-cache openssl
	if [ $? -ne 0 ]; then
		echo "[ERROR] Failed to install openssl by apk(ALPINE)."
		exit 1
	fi
fi

#----------------------------------------------------------
# Create openssl.cnf 
#----------------------------------------------------------
if [ ! -f "${ORG_OPENSSL_CNF}" ]; then
	echo "[ERROR] Could not find file ${ORG_OPENSSL_CNF}"
	exit 1
fi

#
# Create openssl.cnf from /etc/pki/tls/openssl.cnf
# Modify values
#	unique_subject		= no						in [ CA_default ] section
#	email_in_dn			= no						in [ CA_default ] section
#	rand_serial			= no						in [ CA_default ] section
#	unique_subject		= no						in [ CA_default ] section
#	dir      			= <K2HDKC DBaaS K8S domain>	in [ CA_default ] section
#	keyUsage 			= cRLSign, keyCertSign		in [ v3_ca ] section
#	countryName			= optional					in [ policy_match ] section
#	stateOrProvinceName = optional					in [ policy_match ] section
#	organizationName	= optional					in [ policy_match ] section
#
sed -e 's/\[[[:space:]]*CA_default[[:space:]]*\]/\[ CA_default ]\nunique_subject = no\nemail_in_dn = no\nrand_serial = no/g' \
	-e 's/\[[[:space:]]*v3_ca[[:space:]]*\]/\[ v3_ca ]\nkeyUsage = cRLSign, keyCertSign/g'						\
	-e "s#^dir[[:space:]]*=[[:space:]]*.*CA.*#dir = ${CERT_WORK_DIR}#g"											\
	-e 's/^[[:space:]]*countryName[[:space:]]*=[[:space:]]*match.*$/countryName = optional/g'					\
	-e 's/^[[:space:]]*stateOrProvinceName[[:space:]]*=[[:space:]]*match.*$/stateOrProvinceName = optional/g'	\
	-e 's/^[[:space:]]*organizationName[[:space:]]*=[[:space:]]*match.*$/organizationName = optional/g'			\
	"${ORG_OPENSSL_CNF}"																						\
	> "${CUSTOM_OPENSSL_CNF}"

if [ $? -ne 0 ]; then
	echo "[ERROR] Could not create file ${CUSTOM_OPENSSL_CNF}"
	exit 1
fi


#
# Add section to  openssl.cnf
#	[ v3_svr_clt ]									add section
#
SAN_SETTINGS=""
if [ -n "${FULL_HOST_NAME}" ]; then
	SAN_SETTINGS="DNS:${FULL_HOST_NAME}"
fi
if [ -n "${LOCAL_HOST_DOMAIN}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${LOCAL_HOST_DOMAIN}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${LOCAL_HOST_DOMAIN}"
	fi
fi
if [ -n "${SHORT_HOST_NAME}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${SHORT_HOST_NAME}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${SHORT_HOST_NAME}"
	fi
fi
if [ -n "${NODOMAIN_HOST_NAME}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${NODOMAIN_HOST_NAME}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${NODOMAIN_HOST_NAME}"
	fi
fi
if [ -n "${LOCAL_HOST_IP}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="IP:${LOCAL_HOST_IP}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, IP:${LOCAL_HOST_IP}"
	fi
fi
{
	echo ""
	echo "[ v3_svr_clt ]"
	echo "basicConstraints=CA:FALSE"
	echo "keyUsage = digitalSignature, keyEncipherment"
	echo "extendedKeyUsage = serverAuth, clientAuth"
	echo "subjectKeyIdentifier=hash"
	echo "authorityKeyIdentifier=keyid,issuer"
	if [ -n "${SAN_SETTINGS}" ]; then
		echo "subjectAltName = ${SAN_SETTINGS}"
	fi
} >> "${CUSTOM_OPENSSL_CNF}"

if [ $? -ne 0 ]; then
	echo "[ERROR] Could not modify file ${CUSTOM_OPENSSL_CNF}"
	exit 1
fi

#----------------------------------------------------------
# Create certificates
#----------------------------------------------------------
#
# Create private key(2048 bit) without passphrase
#
openssl genrsa				\
	-out "${RAW_KEY_FILE}"	\
	2048					\
	>> "${LOG_FILE}" 2>&1

if [ $? -ne 0 ]; then
	echo "[ERROR] Failed to create ${RAW_KEY_FILE} private key."
	exit 1
fi

chmod 0400 "${RAW_KEY_FILE}"
if [ $? -ne 0 ]; then
	echo "[ERROR] Failed to set permission(0400) to ${RAW_KEY_FILE} private key."
	exit 1
fi

#
# Create CSR file
#
openssl req						\
	-new						\
	-key  "${RAW_KEY_FILE}"	\
	-out  "${RAW_CSR_FILE}"	\
	-subj "/C=${SUBJ_CSR_C}/ST=${SUBJ_CSR_S}/O=${SUBJ_CSR_O}/CN=${NODOMAIN_HOST_NAME}"	\
	>> "${LOG_FILE}" 2>&1

if [ $? -ne 0 ]; then
	echo "[ERROR] Failed to create ${RAW_CSR_FILE} CSR file."
	exit 1
fi

#
# Create certificate file
#
openssl ca								\
	-batch								\
	-extensions	v3_svr_clt				\
	-out		"${RAW_CERT_FILE}"		\
	-days		"${CERT_PERIOD_DAYS}"	\
	-passin		"pass:"					\
	-config		"${CUSTOM_OPENSSL_CNF}" \
	-infiles	"${RAW_CSR_FILE}"		\
	>> "${LOG_FILE}" 2>&1

if [ $? -ne 0 ]; then
	echo "[ERROR] Failed to create ${RAW_CERT_FILE} certificate file."
	exit 1
fi

#----------------------------------------------------------
# Set files to /etc/antpickax
#----------------------------------------------------------
COPY_RESULT=0
cp -p "${ORG_CA_CERT_FILE}"	"${CA_CERT_FILE}"		|| COPY_RESULT=1
cp -p "${RAW_CERT_FILE}"	"${SERVER_CERT_FILE}"	|| COPY_RESULT=1
cp -p "${RAW_KEY_FILE}"		"${SERVER_KEY_FILE}"	|| COPY_RESULT=1
cp -p "${RAW_CERT_FILE}"	"${CLIENT_CERT_FILE}"	|| COPY_RESULT=1
cp -p "${RAW_KEY_FILE}"		"${CLIENT_KEY_FILE}"	|| COPY_RESULT=1
chmod 0444 "${CA_CERT_FILE}"						|| COPY_RESULT=1
chmod 0444 "${SERVER_CERT_FILE}"					|| COPY_RESULT=1
chmod 0400 "${SERVER_KEY_FILE}"						|| COPY_RESULT=1
chmod 0444 "${CLIENT_CERT_FILE}"					|| COPY_RESULT=1
chmod 0400 "${CLIENT_KEY_FILE}"						|| COPY_RESULT=1

if [ "${COPY_RESULT}" -ne 0 ]; then
	echo "[ERROR] Failed to copy certificate files."
	exit 1
fi

#
# Cleanup files
#
rm -rf "${CERT_WORK_DIR}"
if [ $? -ne 0 ]; then
	echo "[ERROR] Could not remove directory ${CERT_WORK_DIR}"
	exit 1
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
