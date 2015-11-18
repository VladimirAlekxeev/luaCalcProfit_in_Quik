package.cpath=".\\?.dll;.\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files (x86)\\Lua\\5.1\\loadall.dll;C:\\Program Files (x86)\\Lua\\5.1\\clibs\\loadall.dll;C:\\Program Files\\Lua\\5.1\\?.dll;C:\\Program Files\\Lua\\5.1\\?51.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?.dll;C:\\Program Files\\Lua\\5.1\\clibs\\?51.dll;C:\\Program Files\\Lua\\5.1\\loadall.dll;C:\\Program Files\\Lua\\5.1\\clibs\\loadall.dll"..package.cpath
package.path=package.path..";.\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\?.lua;C:\\Program Files (x86)\\Lua\\5.1\\?\\init.lua;C:\\Program Files (x86)\\Lua\\5.1\\lua\\?.luac;C:\\Program Files\\Lua\\5.1\\lua\\?.lua;C:\\Program Files\\Lua\\5.1\\lua\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\?.lua;C:\\Program Files\\Lua\\5.1\\?\\init.lua;C:\\Program Files\\Lua\\5.1\\lua\\?.luac;"

package.path=package.path..getScriptPath()..'\\?.lua;'

require'QL'
require'elementToStr'

local deals = {total_profit = 0, number_of_all_deals = 0}	-- таблица сделок заполняется в функции setDeal()

local count = 0
local run = true
local d_color = QTABLE_DEFAULT_COLOR

local message = function (str) message(str, 1) end
local toLog = function(str) toLog(getScriptPath()..'\\log.txt', str) end

function priceToStepPrice(price, stepprice)
-- приведение цены к соответствию с шагом цены
	return math.floor(price / stepprice) * stepprice
end

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
	return {price=transact.price, qty=transact.qty, 
			flags=transact.flags, sec_code=transact.sec_code, 
			class_code=transact.class_code, order_num = transact.order_num}
end

function setDeal(transact)
-- получает транзакцию 
-- устанавливает начальные значения сделки
-- возвращает таблицу my_deal

	toLog('set transaction #'..count..' qty = '..transact.qty..', price = '..transact.price..' '..getTransacDirect(transact))
	count = count + 1
	
	local my_deal = {transactions = {}}
	my_deal.transactions[#my_deal.transactions + 1] = transact
	my_deal.open = true
	my_deal.avg_price = transact.price
	my_deal.deal_direct = getTransacDirect(transact)
	my_deal.sum_contracts = transact.qty
	my_deal.sec_code = transact.sec_code
	my_deal.class_code = transact.class_code
	return my_deal
end

function closeDeal(transact)
	toLog('Deal closed')
	local d = deals[transact.sec_code..' '..transact.class_code]
	d.deal = {transactions = {}}
	d.deal.open = false
	d.deal.avg_price = 0
	d.deal.deal_direct = ''
	d.deal.sum_contracts = 0
end

function avgPrice(transact)
	--расчитывает среднюю цену сделки и записывает её
	--в deals[transact.sec_code..' '..transact.class_code].deal.avg_price
	local d = deals[transact.sec_code..' '..transact.class_code]
	local sum_q, sum_p = 0, 0	
	for i = 1, #d.deal.transactions do
		sum_q = sum_q + d.deal.transactions[i].qty
		sum_p = sum_p +d.deal.transactions[i].qty * d.deal.transactions[i].price
	end
	if sum_q ~= 0 then 
		d.deal.avg_price = priceToStepPrice(sum_p / sum_q, 
		getParamEx(transact.class_code, transact.sec_code, "SEC_PRICE_STEP").param_value)
	else d.deal.avg_price = 0 end
	d.deal.sum_contracts = sum_q 
end

function addToDeal(transact)
-- добавляет транзакцию в сделку
	local d = deals[transact.sec_code..' '..transact.class_code]
	if transact.qty ~= 0 then 
		d.deal.transactions[#d.deal.transactions + 1] = extractParam(transact) 
		toLog('add transaction #'..count..' qty = '..transact.qty..', price = '..transact.price..' '..getTransacDirect(transact))
		--d.total_qty = d.total_qty + transact.qty
		count = count + 1
	end	
	avgPrice(transact)
	toLog('avg price of deal = '..d.deal.avg_price..' all qty in deal = '..d.deal.sum_contracts)
end

function difPriceCost(begin_price, end_price, deal)
-- beging_price начальная цена сделки, end_price конечная цена
-- deal - таблица вида "deals[transact.sec_code..' '..transact.class_code]" с параметрами сделки
-- возвращает стоимость разницы в цене
	local dif = 0
	if deal.deal_direct == 'b' then
		dif = end_price - begin_price
	else
		dif = begin_price - end_price
	end
	return dif / getParamEx(deal.class_code, 
							deal.sec_code, "SEC_PRICE_STEP").param_value *	
				getParamEx(deal.class_code, 
							deal.sec_code, "STEPPRICE").param_value
end

function calcDeal(transaction)
-- Принимает транзакцию -- transaction
-- Создаёт в таблице deals, если ещё не существует, ключ 'sec_code cass_code'
-- присваивает ему значение таблицу deal в которой заполняе поля.
	local in_transact = extractParam(transaction)
	local d = deals[in_transact.sec_code..' '..in_transact.class_code] or {}	
	
	if deals[in_transact.sec_code..' '..in_transact.class_code] == nil then
		deals[in_transact.sec_code..' '..in_transact.class_code] = {}
		d = deals[in_transact.sec_code..' '..in_transact.class_code]
		toLog('Deal is opening first time.')
		d.deal= setDeal(in_transact)
		d.number_of_deals = 1	-- кол-во сделок по бумаге или фьючерсу
		d.total_profit = 0 -- общий доход по бумаге или фьючерсу
		d.total_qty = in_transact.qty	-- общее кол-во контрактов в сделках по бумаге или фъючерсу
		deals.number_of_all_deals = deals.number_of_all_deals + 1
	else
		if d.deal.open == false then
			toLog('Deal is opening')
			d.deal = setDeal(in_transact)	
			d.number_of_deals = d.number_of_deals + 1
			d.total_qty = d.total_qty + in_transact.qty
			deals.number_of_all_deals = deals.number_of_all_deals + 1
		else
			if d.deal.deal_direct == getTransacDirect(in_transact) then	-- если транзакция совпадает с напр. сделки.
				toLog('transation adding to deal')
				addToDeal(in_transact)
				d.total_qty = d.total_qty + in_transact.qty
			else
				toLog('closing part of deal')
				toLog('closing transaction #'..count..' qty = '..in_transact.qty..', price = '..in_transact.price..' '..getTransacDirect(in_transact))
				count = count + 1
				-- qty, price - разница в кол-ве контрактов и цене между последней транзакцией в сделке
				-- и транзакцией на закрытие сделки
				local dif = {qty = 0, price = 0}
				local last_deal_tr = {}	-- последняя транзакция в сделке
				-- флаг полного исполнения транзакции противоположной направлению сделки
				local transaction_perormed = false
				while not transaction_perormed do
					last_deal_tr = table.remove(d.deal.transactions) 	--вытаскивает последнюю транзакцию из  deal	
					dif.price_cost = difPriceCost(last_deal_tr.price, in_transact.price, d.deal) 
					dif.qty = last_deal_tr.qty - in_transact.qty
					local profit = 0
					if dif.qty >= 0 then
						profit = in_transact.qty * dif.price_cost
						toLog('profit = '..profit..', dif.price = '..dif.price_cost..' dif.qty = '..dif.qty)						
						last_deal_tr.qty = dif.qty
						addToDeal(last_deal_tr)
						transaction_perormed = true
					else
						profit = last_deal_tr.qty * dif.price_cost
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

function OnInit()
	TableCalcProfit = AllocTable()
	AddColumn(TableCalcProfit, 1, "Name", true, QTABLE_CACHED_STRING_TYPE, 15)
	AddColumn(TableCalcProfit, 2, "Avg Price", true, QTABLE_DOUBLE_TYPE, 15)
	AddColumn(TableCalcProfit, 3, "QTY in Deal", true, QTABLE_INT_TYPE , 15)
	AddColumn(TableCalcProfit, 4, "Total Deals / QTY", true, QTABLE_INT_TYPE , 19)
	AddColumn(TableCalcProfit, 5, "Profit", true, QTABLE_STRING_TYPE , 10)
	AddColumn(TableCalcProfit, 6, "Total profit", true, QTABLE_DOUBLE_TYPE , 20)
	CreateWindow(TableCalcProfit)
	SetWindowPos(TableCalcProfit, 100, 700, 520, 100)
	SetWindowCaption(TableCalcProfit, "Calculation Profit")
	InsertRow(TableCalcProfit, -1)
end

function makeIndicator()
	local i = 0
	return function()
		local str = ' '
		for k = 0, i do
			str = str..str
		end
		i = (i + 1) % 10
		return str..'-'
	end
end

local indicator = makeIndicator()

function viewResult(ch)
	local ch = ch or '0'
	local rows, col = GetTableSize(TableCalcProfit)
	local row = 1
	local profit = 0
	for item, value in pairs(deals) do
		if item ~= 'total_profit' and item ~= 'number_of_all_deals' then
			SetCell(TableCalcProfit, row, 1, item)
			--toLog('value = '..elementToStr(value))
			SetCell(TableCalcProfit, row, 2, tostring(value.deal.avg_price), value.deal.avg_price)
			SetCell(TableCalcProfit, row, 3, tostring(value.deal.sum_contracts), value.deal.sum_contracts)
			SetCell(TableCalcProfit, row, 4, string.format('%d / %d   ',value.number_of_deals, value.total_qty))			
			if value.deal.open then				
				if value.deal.deal_direct == 'b' then
					SetColor(TableCalcProfit, row, 1, RGB(162, 252, 174), d_color, d_color, d_color)
				else
					SetColor(TableCalcProfit, row, 1, RGB(252, 210, 210), d_color, d_color, d_color)
				end
				profit = difPriceCost(value.deal.avg_price, 
									getParamEx(value.deal.transactions[1].class_code, 
												value.deal.transactions[1].sec_code, "LAST").param_value, 
												value.deal) * 
									value.deal.sum_contracts
												
				SetCell(TableCalcProfit, row, 5, tostring('   '..profit))
			else
				SetCell(TableCalcProfit, row, 5, ch)
				SetColor(TableCalcProfit, row, 1, d_color, d_color, d_color, d_color)
			end
			SetCell(TableCalcProfit, row, 6, tostring(value.total_profit), value.total_profit)
			row = row + 1
			if row > rows then
				InsertRow(TableCalcProfit, -1)
			end
		else
			SetCell(TableCalcProfit, rows, 1, 'Total')
			SetCell(TableCalcProfit, rows, 6, tostring(deals.total_profit), deals.total_profit)
		end
	end
end

function OnStop(s)
	run = false
	DestroyTable(TableCalcProfit)
	toLog('################## Program Finished #############################')
end

function main()
	local number_of_items = getNumberOf('trades')
	local start_item, n = 0, 0
	-- toLog('table "trades" cheked')
	
	-- toLog('Price of pricestep  '..getParamEx("SPBFUT", "SRZ5", "STEPPRICE").param_value)
	-- toLog('pricestep  '..getParamEx("SPBFUT", "SRZ5", "SEC_PRICE_STEP").param_value)
	-- toLog('the number of digits after the decimal point  '..getParamEx("SPBFUT", "SRZ5", "SEC_SCALE").param_value)
	
	while run do
		for i = start_item, number_of_items - 1 do
			calcDeal(getItem('trades', i))		
			n = i			
		end
		if n ~= 0 then start_item = n + 1 end	--если хотябы одна итерация цикла прошла
		number_of_items = getNumberOf('trades')
		viewResult(indicator())
		sleep(100)
	end
end