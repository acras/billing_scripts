#este script muda a data inicial dos contratos dos clientes que devem permanecer em trial por mais um mês.
#o Welker manda esta lista e rodamos este script.
#Atenção: Se este script for rodado DEPOIS da geração de recebíveis, então temos que rodar também o script 07.


customer_ids = #colar aqui o array de customer_ids que não devem ser cobrados ainda

data = Date.today + 1.month
month = data.month
year = data.year

customer_ids.each do |customer_id|
  Contract.where(customer_id: customer_id).update_all(active_from: Date.new(year, month))
  puts "Atualizado #{Customer.find(customer_id).name}"
end