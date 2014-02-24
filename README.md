# Amplify::Failover

## Overview

![Architecture Diagram](https://bitbucket.org/syseng/amplify-failover/raw/master/doc/img/mysql_zk_failover.png)

## Running it

To build

    ./build.sh

To run

    ./go

To specify the config file

    FAILOVER_CONFIG=config/myconfig.yaml ./go

To specify the server port

    FAILOVER_CONFIG=config/myconfig.yaml ./go server[8888]


## Privileges Required

### MySQL Watchdog

The MySQL watchdog MySQL user requires the following privileges

- SUPER on *.* to set read_only on and off, stop/start slaves
- PROCESS on *.* to kill attached connections
- ALL PRIVILEGES on the failover database in order to create and read/write to the tracking table

The system user only needs privileges to read the config file and bind to the specified port.

### Application Watchdog

The system user requires the following permissions and privileges

- read the config file and bind to the specified port
- execute the commands specified in application.cmd_on_* in the config file.
  This probably means limited sudo access in order to restart the service.
