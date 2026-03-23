#RICARDO DO FUTURO, LEIA ISSO: essa rotina tem que ir pra classe específica de reports... que faz isso aqui:

# r=Saas::Reports.new
# ActiveRecord::Base.logger=nil
# r.get_new_mrr_potential(m,y)
# r.get_mrr_increase_potential(m,y)


require 'csv'

def gerar_comparacao_receivables_csv(month, year, imprimir_na_tela: true)
  cids = Receivable.where(month: month, year: year, is_recurring: true).collect { |r| r.customer_id }.uniq
  date1 = Date.new(year, month) - 1.month

  # Gera o CSV e armazena em uma string
  csv_string = CSV.generate do |csv|
    # Escreve o cabeçalho
    csv << ["Customer Name", "Total Last Month", "Total This Month"]

    cids.each do |id|
      tot1 = Receivable.where(month: date1.month, year: date1.year, customer_id: id, is_recurring: true, status: ['open', 'paid']).sum(:value).to_s
      tot2 = Receivable.where(month: month, year: year, customer_id: id, is_recurring: true, status: ['open', 'paid']).sum(:value).to_s
      customer_name = Customer.find(id).name

      # Escreve uma linha para cada cliente
      csv << [customer_name, tot1, tot2]
    end
  end

  if imprimir_na_tela
    puts csv_string
  else
    IO.popen('pbcopy', 'w') { |f| f << csv_string }
    puts "Conteúdo copiado para a área de transferência (usando pbcopy, compatível apenas com macOS)."
  end
end

# Exemplo de uso:
# gerar_comparacao_receivables_csv(11, 2024, imprimir_na_tela: true)
# gerar_comparacao_receivables_csv(11, 2024, imprimir_na_tela: false)
