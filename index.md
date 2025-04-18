## Helm Chart for K2HDKC (K2Hash based Distributed Kvs Cluster) DBaaS
This repository defines a **Helm Chart** for deploying [K2HDKC](https://k2hdkc.antpick.ax/index.html) cluster as DBaaS (Database as a Service) on Kubernetes cluster.  
The code in this repository is packaged as Helm Chart and distributed from [Artifact Hub](https://artifacthub.io/packages/helm/k2hdkc/k2hdkc).  

You can download the Helm Chart for K2HDKC from Artifact Hub and use it right away.

![K2HDKC DBaaS](https://dbaas.k2hdkc.antpick.ax/images/top_k2hdkc_helm.png){: width="60%" height="60%"}

## About K2HKDC
K2HDKC (K2Hash based Distributed Kvs Cluster) is a distributed KVS(Key Value Store) clustering system.  
This **K2HDKC Helm Chart** builds K2HDKC as DBaaS.  
The K2HDKC DBaaS uses the **K2HR3** (**K2H**dkc based **R**esource and **R**oles and policy **R**ules) system as its backend.  
[K2HR3](https://k2hr3.antpick.ax/index.html) also provides a [Helm Chart](https://artifacthub.io/packages/helm/k2hdkc/k2hdkc), so you can easily build **K2HDKC** with **K2HR3** on kubernetes by Helm.

## Customization
The following options/values are supported. See values.yaml for more detailed documentation and examples:

| Parameter                            | Type         | Description                                                                                                                         | Default |
|--------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------|---------|
| `nameOverride`                       | optional     | Override release part of fully name, if not specified fullnameOverride value.                                                       | `k2hdkc` |
| `fullnameOverride`                   | optional     | Override fully chart/release name                                                                                                   | n/a     |
| `serviceAccount.create`              | optional     | Specifies whether to create a service account, default is true.                                                                     | true    |
| `serviceAccount.annotations`         | optional     | Annotations to add to the service account, default is empty.                                                                        | {}      |
| `serviceAccount.name`                | optional     | Specifies Service account name, default is empty. If not set and create is true, a name is generated using the fullname template.   | ""      |
| `antpickax.configDir`                | optional     | Configration directory path for AntPickax products.                                                                                 | "/etc/antpickax" |
| `antpickax.certPeriodYear`           | optional     | Period years for self signed certificates using in pods.                                                                            | 5       |
| `dbaas.clusterName`                  | optional     | Specify a cluster name for K2HDKC, default is empty. If not set, a name is Release name(.Release.Name).                             | ""      |
| `dbaas.startManual`                  | optional     | Specifies whether to boot the k2hdkc processes manually. This is a flag for debugging.                                              | false   |
| `dbaas.baseDomain`                   | optional     | Specifies the base domain name for the k2hr3 cluster. The default is empty, if empty k8s.domain is used.                            | ""      |
| `dbaas.k2hr3Tenant`                  | optional     | Specify K2HR3 tenant name for K2HDKC cluster. If empty, the namespace of kubernetes is set as default.                              | ""      |
| `dbaas.server.count`                 | optional     | Specify the server count in K2HKDC cluster.                                                                                         | 2       |
| `dbaas.server.port`                  | optional     | Specify the port number for K2HDKC servers.                                                                                         | 8020    |
| `dbaas.server.ctlport`               | optional     | Specify the control port number for K2HDKC servers.                                                                                 | 8021    |
| `dbaas.slave.count`                  | optional     | Specify the slave count in K2HKDC cluster.                                                                                          | 2       |
| `dbaas.slave.ctlport`                | optional     | Specify the control port number for K2HDKC slaves                                                                                   | 8022    |
| `dbaas.slave.image`                  | optional     | Specifies the docker image for k2hdkc slave container. If empty, the same image as `images.dkc` will be used.                       | ""      |
| `dbaas.slave.command`                | optional     | Specifies the command for k2hdkc slave container. If empty, /bin/sh is set as default.                                              | []      |
| `dbaas.slave.args`                   | optional     | Specifies the args for k2hdkc slave container. If empty, dbaas-k2hdkc-dummyslave.sh is set as default.                              | []      |
| `dbaas.slave.files`                  | optional     | Specifies additional files in configmap. The files must be under chart directory, if not, could not load file contents.             | []      |
| `dbaas.slave.expandFiles`            | optional     | Specifies additional files and its contents(string) in configmap. Each value must have key and content subkey.                      | []      |
| `dbaas.slave.expandFiles[].key`      | optional     | Specify the filename.                                                                                                               | n/a     |
| `dbaas.slave.expandFiles[].contents` | optional     | Specify the file contents(string) to upload.                                                                                        | n/a     |
| `dbaas.env.httpProxy`                | optional     | Specify the HTTP PROXY(ex. "http://proxy.local:8080") for K2HR3 system, default is empty.                                           | ""      |
| `dbaas.env.httpsProxy`               | optional     | Specify the HTTPS PROXY(ex. "http://proxy.local:8080") for K2HR3 system, default is empty.                                          | ""      |
| `dbaas.env.noProxy`                  | optional     | Specify the NO PROXY(ex. "internal,127.1.1.1") for K2HR3 system, default is empty.                                                  | ""      |
| `k2hr3.clusterName`                  | optional     | Specify a cluster name for K2HR3 system, default is empty. If not set, a name is k2hr3.                                             | ""      |
| `k2hr3.baseDomain`                   | optional     | Specifies the base domain name for the K2HR3 system, default is empty. If not set, it is set the domain name for K2HDKC cluster.    | ""      |
| `k2hr3.unscopedToken`                | **required** | Specifies the Unscoped Token for K2HR3 system, this token is used for setting information for K2HDKC cluster.                       | ""      |
| `k2hr3.api.baseName`                 | optional     | Specify the base name for K2HR3 REST API, default is empty in which case r3api will be used.                                        | ""      |
| `k2hr3.api.intPort`                  | optional     | Specify the internal port number for K2HR3 REST API slaves.                                                                         | 443     |
| `mountPoint.configMap`               | optional     | Specify the directory path in each pods to mount the configmap.                                                                     | "/configmap" |
| `mountPoint.ca`                      | optional     | Specify the directory path in each pods to mount the secret which has CA self signed certificates.                                  | "/secret-ca" |
| `mountPoint.k2hr3Token`              | optional     | Specify the directory path in each pods to mount the K2HR3 Unscoped Token file.                                                     | "/secret-k2hr3-token" |
| `images.dkc.fullImageName`           | optional     | Specify the image full name(organaization/name/version) for the K2HDKC.                                                             | ""      |
| `images.dkc.organization`            | optional     | Specify the organaization for the K2HDKC, Valid only when images.app.fullImageName is not specified.                                | ""      |
| `images.dkc.imageName`               | optional     | Specify the image name for the K2HDKC, Valid only when images.app.fullImageName is not specified.                                   | ""      |
| `images.dkc.version`                 | optional     | Specify the image version for the K2HDKC, Valid only when images.app.fullImageName is not specified.                                | ""      |
| `images.chmpx.fullImageName`         | optional     | Specify the image full name(organaization/name/version) for the CHMPX.                                                              | ""      |
| `images.chmpx.organization`          | optional     | Specify the organaization for the CHMPX, Valid only when images.app.fullImageName is not specified.                                 | ""      |
| `images.chmpx.imageName`             | optional     | Specify the image name for the CHMPX, Valid only when images.app.fullImageName is not specified.                                    | ""      |
| `images.chmpx.version`               | optional     | Specify the image version for the CHMPX, Valid only when images.app.fullImageName is not specified.                                 | ""      |
| `images.init.fullImageName`          | optional     | Specify the image full name(organaization/name/version) for the init/setup container.                                               | ""      |
| `images.init.organization`           | optional     | Specify the organaization for the init/setup container, Valid only when images.init.fullImageName is not specified.                 | ""      |
| `images.init.imageName`              | optional     | Specify the image name for the init/setup container, Valid only when images.init.fullImageName is not specified.                    | ""      |
| `images.init.version`                | optional     | Specify the image version for the init/setup container, Valid only when images.init.fullImageName is not specified.                 | ""      |
| `k8s.namespace`                      | optional     | Specify the kubernetes namespace to deploy K2HDKC cluster, default is empty. If not set, use Release.Namespace.                     | ""      |
| `k8s.domain`                         | optional     | Specify the domain name of the kubernetes cluster to deploy K2HDKC cluster.                                                         | "svc.cluster.local" |
| `unconvertedFiles.dbaas`             | optional     | Specify the files(unconverted) to be placed in configmap. Normally, you do not need to change this value.                           | files/*.sh |

## Usage
You can deploy and remove K2HDKC DBaaS to your Kubernetes cluster in the order shown below.

### Add Helm Chart repository
```
$ helm repo add k2hdkc https://helm.k2hdkc.antpick.ax/
```

### Install
You can install by specifying the `release name` and `required options`.  
```
$ helm install <release name> k2hdkc \
    --set k2hr3.unscopedToken=<user access token for k2hr3 oidc> \
    --set k2hr3.clusterName=<optional: k2hr3 system name which is deployed by k2hr3 helm chart>
```

### Test after install
You can check whether the installed Helm Chart is working properly as follows.  
```
$ helm test <release name>
```

### Uninstall
You can uninstall the installed Helm Chart by doing the following.  
```
$ helm uninstall <release name>
```

### Other operation
Other operations can be performed using the Helm command.  
See `helm --help` for more information.

## Use with RANCHER
K2HDKC Helm Chart can be used by registering the repository in [RANCHER](https://rancher.com/).  
[RANCHER](https://rancher.com/) allows you to use K2HDKC Helm Chart with more intuitive and simpler operations than using the `helm` command.  
See the [K2HDKC Helm Chart documentation](https://github.com/yahoojapan/k2hdkc_helm_chart) for more details.  

## Documents
[K2HDKC DBaaS Document](https://dbaas.k2hdkc.antpick.ax/index.html)  
[K2HDKC Document](https://k2hdkc.antpick.ax/index.html)  
[K2HR3 Document](https://demo.k2hr3.antpick.ax/)

[About AntPickax](https://antpick.ax/)  

## Repositories
[K2HDKC Helm Chart](https://github.com/yahoojapan/k2hdkc_helm_chart)  
[K2HDKC DBaaS](https://github.com/yahoojapan/k2hdkc_dbaas)  
[K2HDKC](https://github.com/yahoojapan/k2hdkc)  
[K2HR3 Helm Chart](https://github.com/yahoojapan/k2hr3_helm_chart)  
[K2HR3](https://github.com/yahoojapan/k2hr3)  

## License
This software is released under the MIT License, see the license file.

## AntPickax
K2HDKC is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2022 Yahoo Japan Corporation.
