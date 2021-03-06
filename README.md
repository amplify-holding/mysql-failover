# Amplify::Failover

## Overview

![Architecture Diagram](https://raw.githubusercontent.com/amplify-holding/mysql-failover/master/doc/img/mysql_zk_failover.png)

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

- `SUPER on *.*` to set read_only on and off, stop/start slaves
- `PROCESS on *.*` to kill attached connections
- `ALL PRIVILEGES` on the failover database in order to create and read/write to the tracking table

The system user only needs privileges to read the config file and bind to the specified port.

### Application Watchdog

The system user requires the following permissions and privileges

- read the config file and bind to the specified port
- execute the commands specified in `application.cmd_on_*` in the config file.
  This probably means limited sudo access in order to restart the service.

## How to Fail Over A Database
Any of these commands may be executed by SSHing into any node within an environment and application that is running the failover watchdog.  For example, mysql-001, mysql-002, web-001, web-002 all run the failover watchdog for the named application.

### To list available fail over targets
```
$ sudo java -jar /opt/failover/failover.war -S bin/failover -c /etc/failover/failover.yaml list
Available fail over targets (* denotes currently active master):
* mysql-001
  mysql-002
```

### To fail over to a new database
```
$ sudo java -jar /opt/failover/failover.war -S bin/failover -c /etc/failover/failover.yaml failover mysql-002
I, [2014-03-12T17:39:12.662000 #1969]  INFO -- : Failing over to mysql-002...
I, [2014-03-12T17:39:13.050000 #1969]  INFO -- : /failover_state changed.  New value: transitioning
I, [2014-03-12T17:39:13.054000 #1969]  INFO -- : State changed to transitioning
I, [2014-03-12T17:39:13.055000 #1969]  INFO -- : Failover in progress...
I, [2014-03-12T17:39:13.115000 #1969]  INFO -- : /failover_state changed.  New value: complete
I, [2014-03-12T17:39:13.116000 #1969]  INFO -- : State changed to complete
I, [2014-03-12T17:39:13.122000 #1969]  INFO -- : Failover complete.
```

Failing over to a new database can take at least 60 seconds, depending on the value of `mysql.tracking_max_wait_secs` in `failover.yml`.  If it takes more than 2x `tracking_max_wait_secs`, something might be stuck and you should look at the logs on other hosts.

