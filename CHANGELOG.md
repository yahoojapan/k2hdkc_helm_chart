<!--
K2HDKC DBaaS Helm Chart

Copyright 2022 Yahoo Japan Corporation.

K2HDKC DBaaS is a DataBase as a Service provided by Yahoo! JAPAN
which is built K2HR3 as a backend and provides services in
cooperation with Kubernetes.
The Override configuration for K2HDKC DBaaS serves to connect the
components that make up the K2HDKC DBaaS. K2HDKC, K2HR3, CHMPX,
and K2HASH are components provided as AntPickax.

For the full copyright and license information, please view
the license file that was distributed with this source code.

AUTHOR:   Takeshi Nakatani
CREATE:   Fri Jan 21 2021
REVISION:
-----------------------------------------------------------

[About This file]
This file format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and the version in this repository adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

In addition, the following rules apply to this file update.
This file is updated only when it is released and published,
because it is difficult to operate this file every time the
file is updated or changed.
Therefore, we do not use [Unreleased] in this file.

The items should be added in each release are as follows:
	-----------------
	## [0.0.0] - YYYY-MM-DD
	### Chnaged
	- Commit message - #<PR number>
	- ...
	
	...
	...
	
	[x.x.x]: https://github.com/yahoojapan/k2hdkc_helm_chart/compare/v0.0.0...v0.0.1
	....
	-----------------
Please have a comparison link which is at the end of the
file ready.
-->
# Change Log for K2HDKC Helm Chart

## [1.0.3] - 2023-11-02
### Changed
- Changed the default version for Docker images

## [1.0.2] - 2022-10-25
### Changed
- Updated .helmignore file
- Added flexibility such as PROXY environment and Image selection
- Fixed bugs about shellscript contidion
- Updated header and footer in comment lines
- Updated issue/pullrequest templates
- Reviewed ShellCheck processing
- Updated ci.yml for upgrading actions/checkout
- Updated azure/setup-helm from v1 to v3
- Updated helm_packager.sh for changing grep parameter

## [1.0.1] - 2022-03-11
### Changed
- Supported RANCHER as RANCHER Helm Chart

## [1.0.0] - 2022-02-09
### Changed
- Initial Commit and publishing

[1.0.3]: https://github.com/yahoojapan/k2hdkc_helm_chart/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/yahoojapan/k2hdkc_helm_chart/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/yahoojapan/k2hdkc_helm_chart/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/yahoojapan/k2hdkc_helm_chart/compare/9a17586...v1.0.0
