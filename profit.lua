package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"

package.path=package.path..getScriptPath()..'\\?.lua;'


local deals ={
	deals = {},
	total_deals = 0,
	total_profit = 0
}

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
	if bit.band(transact['flags'],4)>0
	then return 's'
	else return 'b'
	end
end

function extractParam(transact)
-- получает транзакцию из таблицы сделок
-- возвращает таблицу с параметрами транзакции
	return {price=transact.price, qty=transact.qty, flags=transact.flags}
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

function avgPrice(deal)
-- возвращает среднюю цену сделки
	local sum_pr, sum_qty = 0, 0
	for i = 1, #deal.transactions do
		sum_qty = sum_qty + deal.transactions[i].qty
		sum_pr = sum_pr + deal.transactions[i].qty * deal.transactions[i].price
	end
	return sum_pr / sum_qty
end

function getProfit(transact)
	local deal = deals.deals[transact.sec_code..' '..transact.class_code]
	local profit, tr = {}, 0
	local difference = {}
	if deal.deal_direct == 'b' then
		tr = table.remove(deal.transactions)
		if tr.qty > transact.qty then
			difference.qty = tr.qty - transact.qty
			difference.price = transact.price - tr.price
			profit = difference.price * transact.qty
			tr.qty = difference.qty
			deal.trasactions[#deal.trasactions + 1] = tr
			deal.avg_price = avgPrice(deal)
		elseif tr.qty < transact.qty then
			difference.qty = transact.qty - tr.qty
			difference.price = transact.price - tr.price
			profit = difference.price * tr.qty
			tr.qty = difference.qty
			deal.trasactions[#deal.trasactions + 1] = tr
			deal.avg_price = avgPrice(deal)
		end
	else
	end
end

function addToDeal(transact)
	local deal = deals.deals[transact.sec_code..' '..transact.class_code]
	if deal.deal_direct == getTransacDirect(transact) then	-- если транзакция совпадает с напр. сделки.
		deal.transactions[#deal.transactions + 1] = extractParam(transact)	
		deal.avg_price = avgPrice(deal)
	else
		
	end
end

function calcDeal(transaction)
	local deal = deals.deals[transaction.sec_code..' '..transaction.class_code]
	if deal.open == false then
		deal = setDeal(transaction)
	else
		addToDeal(transaction)
	end
end

function main()
	local number_of_items = getNumberOf('trades')
	local trade = {}
	for i = 0, number_of_items - 1 do
		trade = getItem('trades', i)
		if deals.deals[trade.sec_code..' '..trade.class_code] ~= nil then
			calcDeal(trade)
		else
			deals.deals[trade.sec_code..' '..trade.class_code] = setDeal(trade)
		end
	end	
	--message(dealToString(deals.deals[trade.sec_code..' '..trade.class_code]))
end