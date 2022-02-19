> NOTE: The ICN project is presently in the incubation/pre-production
> phase and is suitable for testing purposes only.

# Introduction

ICN addresses the infrastructure orchestration needed to bring up a
site using baremetal servers. It strives to automate the process of
installing a jump server (Local Controller) to the greatest degree
possible – "zero touch installation". Once the jump server is booted
and the compute cluster-specific values are provided, the controller
begins to inspect and provision the baremetal servers until the
cluster is entirely configured.

# Table of Contents
1. [Quick start](doc/quick-start.md)
2. [Installation guide](doc/installation-guide.md)
3. [Troubleshooting](doc/troubleshooting.md)

# Reporting a bug

Please report any issues found in the [ICN
JIRA](https://jira.akraino.org/projects/ICN/issues).  A Linux
Foundation ID must be created first.

# License
Apache license v2.0

```
/*
* Copyright 2019-2022 Intel Corporation, Inc
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
```
