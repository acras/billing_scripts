# Script para encontrar contagens (SaasDfeCount) duplicadas
# para um mês/ano/customer_id/cnpj específico

def encontra_duplicatas_saas_dfe_count(month, year, customer_id = nil, cnpj = nil)
  puts "=== ANÁLISE DE DUPLICATAS SaasDfeCount ==="
  puts "Mês: #{month}, Ano: #{year}"
  puts "Customer ID: #{customer_id || 'Todos'}"
  puts "CNPJ: #{cnpj || 'Todos'}"
  puts "=" * 50
  
  # Construir a query base
  query = SaasDfeCount.where(month: month, year: year)
  query = query.where(customer_id: customer_id) if customer_id
  query = query.where(cnpj: cnpj) if cnpj
  
  # Encontrar duplicatas agrupando por customer_id, cnpj, document_type
  duplicatas = query.group(:customer_id, :cnpj, :document_type)
                    .having('count(*) > 1')
                    .count
  
  if duplicatas.empty?
    puts "✅ Nenhuma duplicata encontrada!"
    return []
  end
  
  puts "❌ Encontradas #{duplicatas.size} combinações com duplicatas:"
  puts
  
  resultados = []
  
  duplicatas.each do |(customer_id, cnpj, document_type), count|
    puts "Customer ID: #{customer_id}, CNPJ: #{cnpj}, Tipo: #{document_type} (#{count} registros)"
    
    # Buscar todos os registros duplicados
    registros = SaasDfeCount.where(
      customer_id: customer_id,
      cnpj: cnpj,
      document_type: document_type,
      month: month,
      year: year
    ).order(:id)
    
    registros.each_with_index do |registro, index|
      puts "  #{index + 1}. ID: #{registro.id}, Count: #{registro.document_count}, Customer ID: #{registro.customer_id}, CNPJ: #{registro.cnpj}, Tipo Doc: #{registro.document_type},Created: #{registro.created_at}"
    end
    
    resultados << {
      customer_id: customer_id,
      cnpj: cnpj,
      document_type: document_type,
      count: count,
      registros: registros
    }
    
    puts
  end
  
  puts "=" * 50
  puts "Total de combinações com duplicatas: #{duplicatas.size}"
  
  resultados
end

def remove_duplicatas_saas_dfe_count(month, year, customer_id = nil, cnpj = nil, dry_run = true)
  puts "=== REMOÇÃO DE DUPLICATAS SaasDfeCount ==="
  puts "MODO: #{dry_run ? 'SIMULAÇÃO' : 'EXECUÇÃO REAL'}"
  puts "=" * 50
  
  duplicatas = encontra_duplicatas_saas_dfe_count(month, year, customer_id, cnpj)
  
  if duplicatas.empty?
    puts "Nada a remover."
    return
  end
  
  total_removidos = 0
  
  duplicatas.each do |duplicata|
    registros = duplicata[:registros]
    
    # Manter o primeiro registro (mais antigo) e remover os demais
    registros_para_remover = registros[1..-1]
    
    puts "Removendo #{registros_para_remover.size} registros duplicados para:"
    puts "  Customer ID: #{duplicata[:customer_id]}, CNPJ: #{duplicata[:cnpj]}, Tipo: #{duplicata[:document_type]}"
    
    registros_para_remover.each do |registro|
      if dry_run
        puts "  [SIMULAÇÃO] Removeria ID: #{registro.id} (Count: #{registro.document_count})"
      else
        puts "  Removendo ID: #{registro.id} (Count: #{registro.document_count})"
        registro.destroy
      end
      total_removidos += 1
    end
    puts
  end
  
  puts "=" * 50
  puts "Total de registros #{dry_run ? 'que seriam removidos' : 'removidos'}: #{total_removidos}"
end

# Exemplos de uso:

# 1. Encontrar duplicatas para um mês/ano específico
# encontra_duplicatas_saas_dfe_count(1, 2024)

# 2. Encontrar duplicatas para um customer_id específico
# encontra_duplicatas_saas_dfe_count(1, 2024, 12345)

# 3. Encontrar duplicatas para um CNPJ específico
# encontra_duplicatas_saas_dfe_count(1, 2024, nil, "12345678000190")

# 4. Simular remoção de duplicatas (não executa)
# remove_duplicatas_saas_dfe_count(1, 2024, dry_run: true)

# 5. Executar remoção de duplicatas (executa de verdade)
# remove_duplicatas_saas_dfe_count(1, 2024, dry_run: false)

puts "Script carregado. Use as funções:"
puts "- encontra_duplicatas_saas_dfe_count(month, year, customer_id, cnpj)"
puts "- remove_duplicatas_saas_dfe_count(month, year, customer_id, cnpj, dry_run)" 