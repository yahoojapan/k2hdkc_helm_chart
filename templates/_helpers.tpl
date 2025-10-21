{{-
/*
*
* K2HDKC DBaaS Helm Chart
*
* Copyright 2022 Yahoo Japan Corporation.
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
* Set k2hr3 tenant name for dbaas.
*
*/}}
{{- define "k2hdkc.k2hr3Tenant" -}}
	{{- $tmpname := default (include "k2hdkc.k8sNamespace" .) .Values.dbaas.k2hr3Tenant }}
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
* Set organization and version fo images
*
* K2HDKC Image ( images.k2hdkcImage )
*/
-}}
{{- define "images.k2hdkcImage" -}}
	{{- if .Values.images.dkc.fullImageName }}
		{{- default "" .Values.images.dkc.fullImageName }}
	{{- else }}
		{{- $tmpdkcorg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpdkcname := "k2hdkc" }}
		{{- $tmpdkcver  := "1.0.17" }}
		{{- if .Values.images.dkc.organization }}
			{{- $tmpdkcorg = .Values.images.dkc.organization }}
		{{- end }}
		{{- if .Values.images.dkc.imageName }}
			{{- $tmpdkcname = .Values.images.dkc.imageName }}
		{{- end }}
		{{- if .Values.images.dkc.version }}
			{{- $tmpdkcver = .Values.images.dkc.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpdkcorg $tmpdkcname $tmpdkcver }}
	{{- end }}
{{- end }}

{{-
/*
* Chmpx Image ( images.chmpxImage )
*/
-}}
{{- define "images.chmpxImage" -}}
	{{- if .Values.images.chmpx.fullImageName }}
		{{- default "" .Values.images.chmpx.fullImageName }}
	{{- else }}
		{{- $tmpchmpxorg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpchmpxname := "chmpx" }}
		{{- $tmpchmpxver  := "1.0.110" }}
		{{- if .Values.images.chmpx.organization }}
			{{- $tmpchmpxorg = .Values.images.chmpx.organization }}
		{{- end }}
		{{- if .Values.images.chmpx.imageName }}
			{{- $tmpchmpxname = .Values.images.chmpx.imageName }}
		{{- end }}
		{{- if .Values.images.chmpx.version }}
			{{- $tmpchmpxver = .Values.images.chmpx.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpchmpxorg $tmpchmpxname $tmpchmpxver }}
	{{- end }}
{{- end }}

{{-
/*
* Init Image ( images.initImage )
*/
-}}
{{- define "images.initImage" -}}
	{{- if .Values.images.init.fullImageName }}
		{{- default "" .Values.images.init.fullImageName }}
	{{- else }}
		{{- $tmpinitorg  := "" }}
		{{- $tmpinitname := "alpine" }}
		{{- $tmpinitver  := "3.22" }}
		{{- if .Values.images.init.organization }}
			{{- $tmpinitorg = .Values.images.init.organization }}
		{{- end }}
		{{- if .Values.images.init.imageName }}
			{{- $tmpinitname = .Values.images.init.imageName }}
		{{- end }}
		{{- if .Values.images.init.version }}
			{{- $tmpinitver = .Values.images.init.version }}
		{{- end }}
		{{- if $tmpinitorg }}
			{{- printf "%s/%s:%s" $tmpinitorg $tmpinitname $tmpinitver }}
		{{- else }}
			{{- printf "%s:%s" $tmpinitname $tmpinitver }}
		{{- end }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* K2HDKC Slave cntainer - image/command/args
*
*/}}
{{- define "k2hdkc.slaveImage" -}}
	{{- if .Values.dbaas.slave.image }}
		{{- .Values.dbaas.slave.image }}
	{{- else -}}
		{{ include "images.k2hdkcImage" . }}
	{{- end }}
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
/*---------------------------------------------------------
* Set PROXY environments.
*
* Schema separation for Base proxy environment
*
*/}}
{{- define "tmp.HttpProxyWS" -}}
	{{- if .Values.dbaas.env.httpProxy }}
		{{- if contains "http://" .Values.dbaas.env.httpProxy }}
			{{- default "" .Values.dbaas.env.httpProxy }}
		{{- else if contains "https://" .Values.dbaas.env.httpProxy }}
			{{- default "" .Values.dbaas.env.httpProxy }}
		{{- else }}
			{{- printf "http://%s" .Values.dbaas.env.httpProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.dbaas.env.httpProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpProxy" -}}
	{{- if .Values.dbaas.env.httpProxy }}
		{{- if contains "http://" .Values.dbaas.env.httpProxy }}
			{{- default "" .Values.dbaas.env.httpProxy | replace "http://" "" }}
		{{- else if contains "https://" .Values.dbaas.env.httpProxy }}
			{{- default "" .Values.dbaas.env.httpProxy | replace "https://" "" }}
		{{- else }}
			{{- default "" .Values.dbaas.env.httpProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.dbaas.env.httpProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpsProxyWS" -}}
	{{- if .Values.dbaas.env.httpsProxy }}
		{{- if contains "http://" .Values.dbaas.env.httpsProxy }}
			{{- default "" .Values.dbaas.env.httpsProxy }}
		{{- else if contains "https://" .Values.dbaas.env.httpsProxy }}
			{{- default "" .Values.dbaas.env.httpsProxy }}
		{{- else }}
			{{- printf "http://%s" .Values.dbaas.env.httpsProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.dbaas.env.httpsProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpsProxy" -}}
	{{- if .Values.dbaas.env.httpsProxy }}
		{{- if contains "http://" .Values.dbaas.env.httpsProxy }}
			{{- default "" .Values.dbaas.env.httpsProxy | replace "http://" "" }}
		{{- else if contains "https://" .Values.dbaas.env.httpsProxy }}
			{{- default "" .Values.dbaas.env.httpsProxy | replace "https://" "" }}
		{{- else }}
			{{- default "" .Values.dbaas.env.httpsProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.dbaas.env.httpsProxy }}
	{{- end }}
{{- end }}

{{-
/*
* PROXY Environment for K2HDKC Container
*/
-}}
{{- define "env.dkc.httpProxy" -}}
	{{- if contains "alpine" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.dkc.httpsProxy" -}}
	{{- if contains "alpine" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.dkc.noProxy" -}}
	{{- default "" .Values.dbaas.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for CHMPX Conatiner
*/
-}}
{{- define "env.chmpx.httpProxy" -}}
	{{- if contains "alpine" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.chmpx.httpsProxy" -}}
	{{- if contains "alpine" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.chmpx.noProxy" -}}
	{{- default "" .Values.dbaas.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for Init/Setup Container
*/
-}}
{{- define "env.init.httpProxy" -}}
	{{- if contains "alpine" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.init.httpsProxy" -}}
	{{- if contains "alpine" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.init.noProxy" -}}
	{{- default "" .Values.dbaas.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for Slave Container
*/
-}}
{{- define "env.slave.httpProxy" -}}
	{{- if contains "alpine" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.slave.httpsProxy" -}}
	{{- if contains "alpine" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "k2hdkc.slaveImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.slave.noProxy" -}}
	{{- default "" .Values.dbaas.env.noProxy }}
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
