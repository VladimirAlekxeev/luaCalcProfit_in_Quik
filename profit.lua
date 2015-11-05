package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"

package.path=package.path..getScriptPath()..'\\?.lua;'


local deals = {total_profit = 0, total_number_of_deals = 0}	-- таблица сделок

local message = function (str) message(str, 1) end

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
	if bit.band(transact.flags,4)>0 then return 's'
	else return 'b'
	end
end

function extractParam(transact)
-- получает транзакцию из таблицы сделок
-- возвращает таблицу с параметрами транзакции
	return {price=transact.price, qty=transact.qty, flags=transact.flags, sec_code = transact.sec_code, class_code = transact.class_code}
end

function setDeal(transact)
-- получает транзакцию из таблицы сделок
-- устанавливает начальные значения сделки
-- возвращает таблицу my_deal
	local my_deal = {transactions = {}}
	my_deal.transactions[#my_deal.transactions + 1] = extractParam(transact)
	my_deal.open = true
	my_deal.avg_price = transact.price
	my_deal.deal_direct = getTransacDirect(transact)
	my_deal.profit = 0
	return my_deal
end

function closeDeal(transact)
	local d = deals[transact.sec_code..' '..transact.class_code]
	d.deal = {transactions = {}}
	d.deal.open = false
	d.deal.avg_price = 0
	d.deal.deal_direct = ''
	d.deal.profit = 0
end

function avgPrice(deal)
-- возвращает среднюю цену сделки
	local sum_pr, sum_qty = 0, 0
	for i = 1, #deal.transactions do
		sum_qty = sum_qty + deal.transactions[i].qty
		sum_pr = sum_pr + deal.transactions[i].qty * deal.transactions[i].price
	end
	return sum_pr / sum_qty
end

function addToDeal(transact)
-- добавляет транзакцию в сделку
	local d = deals[transact.sec_code..' '..transact.class_code]
	if transact.qty ~= 0 then d.deal.transactions[#d.deal.transactions + 1] = extractParam(transact) end	
	d.deal.avg_price = avgPrice(d.deal)
end

function calcDeal(transaction)
-- В РАЗРАБОТКЕ
	local d = deals[transaction.sec_code..' '..transaction.class_code]
	if d.deal.open == false then
		d.deal = setDeal(transaction)
		d.total_deals = d.total_deals + 1
		deals.total_number_of_deals = deals.total_number_of_deals + 1
	else
		if d.deal.deal_direct == getTransacDirect(transaction) then	-- если транзакция совпадает с напр. сделки.
			addToDeal(transaction)
		else
			-- qty, price - разница в кол-ве контрактов и цене между последней транзакцией в сделке
			-- и транзакцией на закрытие сделки
			local dif = {qty = 0, price = 0}
			local tr = {}	-- последняя транзакция в сделке
			local transaction_perormed = false	-- флаг полного исполнения транзакции
			while not transaction_perormed do
				tr = table.remove(d.deal.transactions) 	--вытаскивает последнюю транзакцию из  deal				
				if d.deal.deal_direct == 'b' then
					dif.price = transaction.price - tr.price
				else
					dif.price = tr.price - transaction.price
				end
				dif.qty = tr.qty - transaction.qty
				if dif.qty > 0 or dif.qty == 0 then
					d.total_profit = d.total_profit + transaction.qty * dif.price
					tr.qty = dif.qty
					addToDeal(tr)
					transaction_perormed = true
				else
					d.total_profit = d.total_profit + tr.qty * dif.price
				end
				if #d.deal.transactions == 0 then
					closeDeal(transaction)
					transaction_perormed = true
				end
			end
		end
	end
end

function main()
	local number_of_items = getNumberOf('trades')
	local trade = {}
	for i = 0, number_of_items - 1 do
		trade = getItem('trades', i)
		if deals[trade.sec_code..' '..trade.class_code] ~= nil then
			calcDeal(trade)
		else
			deals[trade.sec_code..' '..trade.class_code] = {}
			deals[trade.sec_code..' '..trade.class_code].deal= setDeal(trade)
			deals[trade.sec_code..' '..trade.class_code].total_deals = 1	-- кол-во сделок по бумаге или фьючерсу
			deals[trade.sec_code..' '..trade.class_code].total_profit = 0 -- доход по бумаге или фьючерсу
			deals.total_number_of_deals = deals.total_number_of_deals + 1
		end
		if deals[trade.sec_code..' '..trade.class_code].deal.open then
			message(dealToString(deals[trade.sec_code..' '..trade.class_code].deal))
		end
	end	
	--message(dealToString(deals[trade.sec_code..' '..trade.class_code].deal))
end