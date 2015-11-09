package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"

package.path=package.path..getScriptPath()..'\\?.lua;'

require'QL'
require'elementToStr'


local deals = {total_profit = 0, number_of_all_deals = 0}	-- таблица сделок

local message = function (str) message(str, 1) end
local toLog = function(str) toLog(getScriptPath()..'\\log.txt', str) end
local count = 0

function dealToString(deal)
	local str = ''
	for item, value in pairs(deal) do
		if value == nil then
			str = str..item..' = '..tostring('nil')..'\n'
		else
			str = str..item..' = '..tostring(value)..'\n'
		end
	end
	return str
end

function getTransacDirect(transact)
-- получает флаги сделки
-- возвращает направление сделки
	if bit.band(transact.flags, 4) > 0 then return 's'
	else return 'b'
	end
end

function extractParam(transact)
-- получает транзакцию из таблицы сделок
-- возвращает таблицу с нужными параметрами транзакции
	return {price=transact.price, qty=transact.qty, flags=transact.flags, sec_code=transact.sec_code, class_code=transact.class_code}
end

function setDeal(transact)
-- получает транзакцию 
-- устанавливает начальные значения сделки
-- возвращает таблицу my_deal

	toLog('set transaction #'..count..' qty = '..transact.qty..', price = '..transact.price..' '..getTransacDirect(transact))
	count = count + 1
	
	local my_deal = {transactions = {}}
	my_deal.transactions[#my_deal.transactions + 1] = extractParam(transact)
	my_deal.open = true
	my_deal.avg_price = transact.price
	my_deal.deal_direct = getTransacDirect(transact)
	--my_deal.sum_price = transact.qty * transact.price
	my_deal.sum_contracts = transact.qty
	return my_deal
end

function closeDeal(transact)
	toLog('Close Deal')
	local d = deals[transact.sec_code..' '..transact.class_code]
	d.deal = {transactions = {}}
	d.deal.open = false
	d.deal.avg_price = 0
	d.deal.deal_direct = ''
	--d.deal.sum_price = 0
	d.deal.sum_contracts = 0
end

function avgPrice(transact)
	--расчитывает среднюю цену сделки
	local d = deals[transact.sec_code..' '..transact.class_code]
	local sum_q, sum_p = 0, 0	
	for i = 1, #d.deal.transactions do
		sum_q = sum_q + d.deal.transactions[i].qty
		sum_p = sum_p +d.deal.transactions[i].qty * d.deal.transactions[i].price
	end
	if sum_q ~= 0 then d.deal.avg_price = sum_p / sum_q
	else d.deal.avg_price = 0 end
	d.deal.sum_contracts = sum_q 
end

function addToDeal(transact)
-- добавляет транзакцию в сделку
	local d = deals[transact.sec_code..' '..transact.class_code]
	if transact.qty ~= 0 then 
		d.deal.transactions[#d.deal.transactions + 1] = extractParam(transact) 
		toLog('add transaction #'..count..' qty = '..transact.qty..', price = '..transact.price..' '..getTransacDirect(transact))		
		count = count + 1
	end	
	avgPrice(transact)
	toLog('avg price of deal = '..d.deal.avg_price..' all qty = '..d.deal.sum_contracts)
end

function calcDeal(transaction)
-- В РАЗРАБОТКЕ
	local in_transact = extractParam(transaction)
	local d = deals[transaction.sec_code..' '..transaction.class_code] or {}	
	
	if deals[transaction.sec_code..' '..transaction.class_code] == nil then
		deals[transaction.sec_code..' '..transaction.class_code] = {}
		d = deals[transaction.sec_code..' '..transaction.class_code]
		toLog('Deal is opening first time.')
		d.deal= setDeal(transaction)
		d.number_of_deals = 1	-- кол-во сделок по бумаге или фьючерсу
		d.total_profit = 0 -- доход по бумаге или фьючерсу
		deals.number_of_all_deals = deals.number_of_all_deals + 1
	else
		if d.deal.open == false then
			toLog('Deal is opening')
			d.deal = setDeal(in_transact)	
			d.number_of_deals = d.number_of_deals + 1
			deals.number_of_all_deals = deals.number_of_all_deals + 1
		else
			if d.deal.deal_direct == getTransacDirect(in_transact) then	-- если транзакция совпадает с напр. сделки.
				toLog('transation adding to deal')
				addToDeal(in_transact)
			else
				toLog('closing part of deal')
				toLog('closing transaction #'..count..' qty = '..transaction.qty..', price = '..transaction.price..' '..getTransacDirect(transaction))
				count = count + 1
				-- qty, price - разница в кол-ве контрактов и цене между последней транзакцией в сделке
				-- и транзакцией на закрытие сделки
				local dif = {qty = 0, price = 0}
				local last_deal_tr = {}	-- последняя транзакция в сделке
				-- флаг полного исполнения транзакции противоположной направлению сделки
				local transaction_perormed = false
				while not transaction_perormed do
					last_deal_tr = table.remove(d.deal.transactions) 	--вытаскивает последнюю транзакцию из  deal				
					if d.deal.deal_direct == 'b' then
						dif.price = in_transact.price - last_deal_tr.price
					else
						dif.price = last_deal_tr.price - in_transact.price
					end
					dif.qty = last_deal_tr.qty - in_transact.qty
					local profit = 0
					if dif.qty >= 0 then
						toLog('dif.qty = '..dif.qty..', dif.price = '..dif.price)
						profit = in_transact.qty * dif.price
						in_transact.qty = dif.qty
						addToDeal(in_transact)
						transaction_perormed = true
					else
						profit = last_deal_tr.qty * dif.price
						in_transact.qty = -1 * dif.qty	-- неисполненый остаток контрактов во входящей транзакции
					end
					d.total_profit = d.total_profit  + profit
					deals.total_profit = deals.total_profit + profit
					toLog('d.total_profit = '..d.total_profit..' deals.total_profit = '..deals.total_profit)
					if #d.deal.transactions == 0 then	-- если больше нет транзакций в сделке
						toLog('Deal is closing')
						closeDeal(in_transact)
						toLog('******************************************************************************************')
						if dif.qty < 0 then		-- если остались не закрытые контракты во входящей транзакции
							toLog('Opening new revers deal')
							d = setDeal(in_transact)	-- открывается сделка в противоположном направлении
						end
						transaction_perormed = true
					end
				end
			end
		end
	end
	
end
local run = true

function OnStop(s)
 run = false
end

function OnTrade(trade)
	message('OnTrade worked!')
	calcDeal(trade)
end
--стоимость шага цены
-- getParamEx("SPBFUT", "BRJ5", "STEPPRICE").param_value

function main()
	local number_of_items = getNumberOf('trades')
	local trade = {}
	for i = 0, number_of_items - 1 do
		trade = getItem('trades', i)
		calcDeal(trade)		
	end	
	--toLog(getParamEx("SPBFUT", "SRZ5", "STEPPRICE").param_value)
	while run do
	sleep(50)
	end
end