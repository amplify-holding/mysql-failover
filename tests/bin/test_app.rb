#!/usr/bin/env ruby

require 'sequel'
require 'sinatra'
require 'sinatra/contrib'
require 'logger'
require 'jdbc/mysql'
require 'json'
require 'zk'

LOGGER = Logger.new($stderr)
LOGGER.level = Logger::DEBUG

ZKOBJ = ZK.new('zk1.vagrant.dev:2181', chroot: '/dev/app/mysql_failover')
mysql_cfg = JSON.parse(ZKOBJ.get('/client_data').first, symbolize_names: true)
LOGGER.debug mysql_cfg.inspect

MYSQL_HOST     = mysql_cfg[:mysql_host]
MYSQL_PORT     = mysql_cfg[:mysql_port] || 3306
MYSQL_USER     = 'failover'
MYSQL_PASSWORD = 'failover'

Jdbc::MySQL.load_driver
DB = Sequel.connect(adapter:        'jdbc',
                    uri:            "jdbc:mysql://#{MYSQL_HOST}:#{MYSQL_PORT}/failover",
                    user:           MYSQL_USER,
                    password:       MYSQL_PASSWORD,
                    sql_log_level:  :debug,
                    logger:         LOGGER )


get '/' do
  DB['select 1'].all
  json :mysql => {
      :host => DB['SELECT @@hostname hostname'].first[:hostname],
      :port => DB['SELECT @@port port'].first[:port]
    }

end
