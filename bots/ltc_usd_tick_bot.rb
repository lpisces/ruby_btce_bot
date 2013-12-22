require 'btce'
require 'mysql2'

ticker = Btce::Ticker.new "ltc_usd"
mysql = Mysql2::Client.new(:host => "localhost", :username => "root")

sql = "INSERT INTO ltc_usd_ticks (last, sell, buy, updated) values ('#{ticker.last}', '#{ticker.sell}', '#{ticker.buy}', '#{ticker.server_time}')"
mysql.query('use btce')
mysql.query(sql)

p sql

