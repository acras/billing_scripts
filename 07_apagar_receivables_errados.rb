#esse só precisa rodar se foram gerados receivables para clientes que não deveriam ser ativados.
#esse caso já é resolvido no script 01 então provavelmente não precisa rodar mais. 

ids = []

#preencher ano e mes corretos
year = 
month =

ids.each do |id|
  Receivable.where(customer_id: id, status: ['open'], lancamento_id: nil).delete_all
  Contract.where(customer_id: id).update_all(active_from: Date.new(year,month))
end