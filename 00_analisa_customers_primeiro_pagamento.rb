#rodamos pró-ativamente no dia 20 de cada mês, a saída deste script é uma lista de clientes que, se nada for alterado
#terá sua primeira mensalidade neste ciclo. Esta lista deve ser enviada ao Welker para que ele analise
#os clientes que devem permanecer em trial.
#O Welker retorna a lista de ids dos clientes que não devem ser cobrados. Esta lista pode ser usada nos scripts
#01 e/ou 07. Leia os scripts para entender quando usar.

load 'saas/invoice2.rb'

def customers_to_activate(month, year)
    r = []
    i2 = Saas::Invoice2.new
    active_customer_ids = i2.active_customer_ids_on(month, year)
    active_customer_ids.each do |customer_id|
      algum_contrato_ativo = Contract.where(customer_id: customer_id, status: 'active').any?
      algum_receivable_pago_ou_aberto = Receivable.where(customer_id: customer_id, is_recurring: true, status: ['open','paid']).any?
      r << customer_id  if (!algum_contrato_ativo && !algum_receivable_pago_ou_aberto)
    end
    r.each do |customer_id|
      c = Customer.find(customer_id)
      puts "#{c.name} - https://capivara.focusnfe.com.br/admin/financeiro/clientes/#{c.id}"
    end
    nil
end

puts "uso: customers_to_activate(month, year)"