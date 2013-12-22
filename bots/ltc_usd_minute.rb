require 'btce'
require 'mysql2'

mysql = Mysql2::Client.new(:host => "localhost", :username => "root")
mysql.query('use btce')

now = Time.new.utc.to_i
close = now - (now % 60)
open = close - 60
max_last = min_last = open_last = close_last = -1

mysql.query("select max(last) as max_last from ltc_usd_ticks where updated >= #{open} and updated <= #{close}").each(:symbolize_keys => true) do |row|
  max_last = row[:max_last]
end

mysql.query("select min(last) as min_last from ltc_usd_ticks where updated >= #{open} and updated <= #{close}").each(:symbolize_keys => true) do |row|
  min_last = row[:min_last]
end
rows = mysql.query("select last from ltc_usd_ticks where updated >= #{open} and updated <= #{close} order by id").each(:as => :array)
open_last = rows[0].last
close_last = rows[-1].last

mysql.query("insert into ltc_usd_minute(open, close, high, low, updated) values ('#{open_last}', '#{close_last}', '#{max_last}', '#{min_last}', '#{close}')")


log = Logger.new('../logs/ltc_usd_minute.log')
log.info("insert into ltc_usd_minute(open, close, high, low, updated) values ('#{open_last}', '#{close_last}', '#{max_last}', '#{min_last}', '#{close}')")
