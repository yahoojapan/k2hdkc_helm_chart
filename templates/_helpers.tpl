{{-
/*
*
* K2HDKC DBaaS Helm Chart
*
* Copyright 2022 Yahoo! Japan Corporation.
*
* K2HDKC DBaaS is a DataBase as a Service provided by Yahoo! JAPAN
* which is built K2HR3 as a backend and provides services in
* cooperation with Kubernetes.
* The Override configuration for K2HDKC DBaaS serves to connect the
* components that make up the K2HDKC DBaaS. K2HDKC, K2HR3, CHMPX,
* and K2HASH are components provided as AntPickax.
*
* For the full copyright and license information, please view
* the license file that was distributed with this source code.
*
* AUTHOR:   Takeshi Nakatani
* CREATE:   Fri Jan 21 2021
* REVISION:
*
*/ -}}

{{-
/*---------------------------------------------------------
* Expand the name of the chart.
*
*/}}
{{- define "k2hdkc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create a default fully qualified app name
*
* We truncate at 63 chars because some Kubernetes name fields are
* limited to this (by the DNS naming spec).
* If release name contains chart name it will be used as a full
* name.
*
*/}}
{{- define "k2hdkc.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set k2hdkc dbaas cluster name.
*
*/}}
{{- define "k2hdkc.clusterName" -}}
{{- $tmpname := default .Release.Name .Values.dbaas.clusterName }}
{{- printf "%s" $tmpname | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set k2hr3 cluster name for dbaas.
*
*/}}
{{- define "k2hdkc.k2hr3ClusterName" -}}
{{- $tmpname := default "k2hr3" .Values.k2hr3.clusterName }}
{{- printf "%s" $tmpname | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set kubernetes namespace.
*
*/}}
{{- define "k2hdkc.k8sNamespace" -}}
{{- $tmpname := default .Release.Namespace .Values.k8s.namespace }}
{{- printf "%s" $tmpname }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set base domain(fqdn) for dbaas.
*
*/}}
{{- define "k2hdkc.dbaasBaseDomain" -}}
{{- $tmpdomain := default "svc.cluster.local" .Values.k8s.domain }}
{{- default $tmpdomain .Values.dbaas.baseDomain }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set variables for k2hr3 api system.
*
*/}}

{{- define "k2hdkc.k2hr3BaseDomain" -}}
{{- default (include "k2hdkc.dbaasBaseDomain" .) .Values.k2hr3.baseDomain }}
{{- end }}

{{- define "k2hdkc.r3apiBaseName" -}}
{{- if .Values.k2hr3.api.baseName }}
{{- .Values.k2hr3.api.baseName }}
{{- else }}
{{- $tmpbasename := include "k2hdkc.k2hr3ClusterName" . }}
{{- printf "r3api-%s" $tmpbasename }}
{{- end }}
{{- end }}

{{- define "k2hdkc.r3apiIntSvcFullname" -}}
{{- printf "svc-%s.%s.%s" (include "k2hdkc.r3apiBaseName" .) (include "k2hdkc.k8sNamespace" .) (include "k2hdkc.k2hr3BaseDomain" .) }}
{{- end }}

{{- define "k2hdkc.r3apiIntPort" -}}
{{- default 443 .Values.k2hr3.api.intPort }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create chart name and version as used by the chart label.
*
*/}}
{{- define "k2hdkc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Common labels
*
*/}}
{{- define "k2hdkc.labels" -}}
helm.sh/chart: {{ include "k2hdkc.chart" . }}
{{ include "k2hdkc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{-
/*---------------------------------------------------------
* Selector labels
*
*/}}
{{- define "k2hdkc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k2hdkc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create the name of the service account to use
*
*/}}
{{- define "k2hdkc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k2hdkc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create self-signed CA and server certs
*
* [NOTE] not set subjects for country etc...
*
*/}}
{{- define "k2hdkc.certPeriodDays" -}}
{{- int (mul .Values.antpickax.certPeriodYear 365) }}
{{- end }}

{{-
/*---------------------------------------------------------
* K2HDKC Slave cntainer - image/command/args
*
*/}}
{{- define "k2hdkc.slaveImage" -}}
{{- default "antpickax/k2hdkc:latest" .Values.dbaas.slave.image }}
{{- end }}

{{- define "k2hdkc.slaveCommand" -}}
{{- if .Values.dbaas.slave.command }}
{{- $needSep := false -}}
command: [
{{- range .Values.dbaas.slave.command }}
{{- if $needSep -}}
,
{{- end }}
{{- . | quote }}
{{- $needSep = true }}
{{- end -}}
]
{{- else -}}
command: ["/bin/sh"]
{{- end }}
{{- end }}

{{- define "k2hdkc.slaveArgs" -}}
{{- if .Values.dbaas.slave.args }}
{{- $needSep := false -}}
args: [
{{- range .Values.dbaas.slave.args }}
{{- if $needSep -}}
,
{{- end }}
{{- . | quote }}
{{- $needSep = true }}
{{- end -}}
]
{{- else }}
{{- if empty .Values.dbaas.slave.command -}}
args: ["{{ .Values.mountPoint.configMap }}/dbaas-k2hdkc-dummyslave.sh"]
{{- end }}
{{- end }}
{{- end }}

{{-
/*
* Local variables:
* tab-width: 4
* c-basic-offset: 4
* End:
* vim600: noexpandtab sw=4 ts=4 fdm=marker
* vim<600: noexpandtab sw=4 ts=4
*
*/ -}}
