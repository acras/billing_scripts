#Excluir contagens de iFood, Localiza e Locaweb da NFSeNR, pois está ativa para nossos testes internos.

print "Mês: "
month = gets.strip.to_i
print "Ano: "
year = gets.strip.to_i

scope = SaasDfeCount.where(customer_id: [987754, 1869066, 2025811], month: month, year: year, document_type: 'nfsenr')

scope.all.each do |c|
    puts "#{Customer.find(c.customer_id).name}: #{c.document_count}" if c.document_count > 0
end

print "Apagar? "
if gets.strip.upcase == 'S'
    scope.delete_all
end