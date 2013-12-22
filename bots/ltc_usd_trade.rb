require 'btce'
require 'mysql2'

def ma(timestamp, minutes, size)
  minute_size = minutes * size
  mysql = Mysql2::Client.new(:host => "localhost", :username => "root")
  mysql.query('use btce')
  rows = mysql.query("select * from ltc_usd_minute where updated < #{timestamp} order by updated desc limit #{minute_size}").each(:symbolize_keys => true)
  arr = []
  rows.each_with_index do |r, i|
    if (i % minutes == minutes - 1)
      arr.push r[:close]
    end
  end
  sum = 0
  arr.each {|c| sum += c}
  size = arr.size > size ? size : arr.size
  return sum/size
end

def ma5(timestamp, minutes)
  return ma(timestamp, minutes, 5)
end

def ma10(timestamp, minutes)
  return ma(timestamp, minutes, 10)
end

def ma20(timestamp, minutes)
  return ma(timestamp, minutes, 20)
end

def ma30(timestamp, minutes)
  return ma(timestamp, minutes, 30)
end

def close(timestamp)
  mysql = Mysql2::Client.new(:host => "localhost", :username => "root")
  mysql.query('use btce')
  rows = mysql.query("select * from ltc_usd_minute where updated < #{timestamp} order by updated desc limit 1").each(:symbolize_keys => true)
  return rows.empty? ? -1 : rows[0][:close]
end

#多头均线
def bull_avg(timestamp, minutes)
  return true if ma5(timestamp, minutes) > ma10(timestamp, minutes) and ma10(timestamp, minutes) > ma20(timestamp, minutes)
  return false
end

#空头均线
def bear_avg(timestamp, minutes)
  return true if ma5(timestamp, minutes) < ma10(timestamp, minutes) and ma10(timestamp, minutes) < ma20(timestamp, minutes)
  return false
end

#5日线高于10日 现价高于5日线 买入
def  buy_cond_1(timestamp, minutes, ticker)
  return true if ma5(timestamp, minutes) > ma10(timestamp, minutes) and ticker.last.to_f > ma5(timestamp, minutes)
  return false
end

#5日线低于10日线， 股价低于5日线 卖出
def  sell_cond_1(timestamp, minutes, ticker)
  return true if ma5(timestamp, minutes) < ma10(timestamp, minutes) and ticker.last.to_f < ma5(timestamp, minutes)
  return false
end

#以下是交易函数
def buy(ticker, amount, max_usd = 10)
  now = Time.new.utc.to_i + 960
  last = last_trade_timestamp
  log = Logger.new('../logs/ltc_usd_trade.log')
  if (last > now) or (now - last < 30 * 60)
    log.info("#{Time.new.utc.to_s}: less than 30 minutes since last trade. B")
    return false
  end
  rate = ticker.sell
  amount_max = (max_usd / ticker.last) * 0.99
  amount = (amount > amount_max) ? amount_max : amount
  amount = format("%.3f",amount).to_f
  r = Btce::TradeAPI.new_from_keyfile.trade(:pair => 'ltc_usd', :type => 'buy', :rate => rate, :amount => amount)
  log.info("#{Time.new.utc.to_s}: Buy Ltc #{amount} @#{rate}.")
  log.info("#{Time.new.utc.to_s}: #{r.to_s}")
end

def sell(ticker, amount, max_usd = 10)
  now = Time.new.utc.to_i + 960
  last = last_trade_timestamp
  log = Logger.new('../logs/ltc_usd_trade.log')
  if (last > now) or (now - last < 30 * 60)
    log.info("#{Time.new.utc.to_s}: less than 30 minutes since last trade. S")
    return false
  end
  rate = ticker.sell
  amount_max = (max_usd / ticker.last) * 0.99
  amount = (amount > amount_max) ? amount_max : amount
  amount = format("%.3f",amount).to_f
  r = Btce::TradeAPI.new_from_keyfile.trade(:pair => 'ltc_usd', :type => 'sell', :rate => rate, :amount => amount)
  log.info("#{Time.new.utc.to_s}: Sell Ltc #{amount} @#{rate}.")
  log.info("#{Time.new.utc.to_s}: #{r.to_s}")
end

def last_trade_timestamp
  history = Btce::TradeAPI.new_from_keyfile.trade_history(:pair => 'ltc_usd', :count => 1).to_hash
  if history['success'] == 1
    return history['return'].first[1]['timestamp'].to_i
  else
    return Time.new.utc.to_i + 960
  end
end


ltc = 0
usd = 0
max_usd = 100
avg_minutes = 30
now = Time.new.utc.to_i + 960
info = Btce::TradeAPI.new_from_keyfile.get_info.to_hash
ticker = Btce::Ticker.new "ltc_usd"
log = Logger.new('../logs/ltc_usd_trade.log')

if info['success'] == 1
  ltc = info['return']['funds']['ltc']
  ltc = format("%.3f", ltc).to_f
  usd = info['return']['funds']['usd']
  usd = format("%.3f", usd).to_f
end

market_value = ltc * ticker.last
trade_ltc = usd / ticker.last * 0.99
trade_ltc = format("%.3f", trade_ltc).to_f

if (market_value > max_usd * 0.95)
  log.info("#{Time.new.utc.to_s}: not allowed to buy more coins. market_value:#{market_value} max_usd:#{max_usd}")
  trade_ltc  = 0
end

log.info("#{Time.new.utc.to_s}: last:#{ticker.last} ltc:#{ltc} usd:#{usd}")
log.info("#{Time.new.utc.to_s}: avg_minutes:#{avg_minutes} ma5:#{ma5(now, avg_minutes)} ma10:#{ma10(now, avg_minutes)} ma20:#{ma20(now, avg_minutes)}")

if (market_value.to_f > 0) and bear_avg(now, avg_minutes)
  sell(ticker, ltc, max_usd)
  log.info("#{Time.new.utc.to_s}: sell_1")
elsif (market_value.to_f > 0) and sell_cond_1(now, avg_minutes, ticker)
  sell(ticker, ltc, max_usd)
  log.info("#{Time.new.utc.to_s}: sell_2")
elsif (market_value.to_f > 0) and bull_avg(now, avg_minutes)
  log.info("#{Time.new.utc.to_s}: hold")
elsif (market_value.to_f < max_usd) and buy_cond_1(now, avg_minutes, ticker)
  log.info("#{Time.new.utc.to_s}: buy_1")
  buy(ticker, trade_ltc, max_usd)
elsif (market_value.to_f < max_usd) and bull_avg(now, avg_minutes) and bull_avg(now - 60 * avg_minutes, avg_minutes)
  log.info("#{Time.new.utc.to_s}: buy_2")
  buy(ticker, trade_ltc, max_usd)
elsif (market_value.to_f < 1) and bear_avg(now, avg_minutes)
  log.info("#{Time.new.utc.to_s}: waiting for bull")
else 
  log.info("#{Time.new.utc.to_s}: nothing to do")
end

Btce::TradeAPI.new_from_keyfile.order_list['return'].each do |k, v|
  Btce::TradeAPI.new_from_keyfile.cancel_order(:order_id => k)
end

