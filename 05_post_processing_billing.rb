
## CASO UM: SSCrop não cobrar fixo por CPF duplicado

#Assumir que cada receivable estará calculado com o valor do CNPJ + emissões
#A ideia será rodar todos os receivables, se não for o primeiro daquele CNPJ, desconta o valor fixo
#easy peasy

total_reduzido = 0.0
month = 2
year = 2026
i2=Saas::Invoice2.new
customer_id = 988765
empresas_ja_cobradas = []
Receivable.where(customer_id: customer_id, month: month, year: year, is_recurring: true, status: ['open','paid']).each do |rec|
    if rec && rec.contract && rec.contract.emitentes.first
    documento = rec.contract.emitentes.first.documento
    enabled_docs = i2.get_enabled_docs_for_cnpjs(documento)
    if empresas_ja_cobradas.include? documento
      #se já foi considerado então reduzo o valor unitário do CNPJ
      #rec.value = rec.value - x
      deduzir = 0.0
      deduzir += 22.48 if enabled_docs[:nfe]
      deduzir += 9.9 if enabled_docs[:mde]
      total_reduzido += deduzir
      puts "Empresa #{documento} já cobrada, deduzir (#{rec.value.to_s}) recebível em #{deduzir}"
      rec.value = rec.value - deduzir
      rec.save
    else
      #se ainda não foi considerado não faço nada no valor e só adiciono nas já consideradas
      empresas_ja_cobradas << documento
    end
  else
    puts "Receivable #{rec.id} sem emitente, analisar"
  end
end;nil
puts "Total reduzido: #{total_reduzido.to_s}"

#Criação manual dos receivables de indexação
# SigmaABC: https://capivara.focusnfe.com.br/admin/financeiro/clientes/1390094
# Tarantela Xaxim: https://capivara.focusnfe.com.br/admin/financeiro/clientes/2192382
# Clube dos Autores: https://capivara.focusnfe.com.br/admin/financeiro/clientes/2172319 
# Survey Monkey: 650827
# Promotec https://capivara.focusnfe.com.br/admin/financeiro/clientes/2193970
# Wappi https://capivara.focusnfe.com.br/admin/financeiro/clientes/2179925
# Digipix https://capivara.focusnfe.com.br/admin/financeiro/clientes/2295053

#[1390094,2192382,2172319,650827,2193970,2179925,2295053].each {|id| gera_receivables_indexacao(id, 4, 2026, 0.01, 59.0)}

  def gera_receivables_indexacao(customer_id, month, year, valor_unitario, minimo_contratual = nil)
    start_date = Date.new(year, month)
    end_date = start_date + 1.month
    total_final = 0.0
    Contract.where(customer_id: customer_id).
            where(status: ['A', 'C', 'S']).
            where("active_from <= ? AND (active_to IS NULL OR active_to >= ?)", start_date, end_date).
            all.each do |c|
      count = SaasDfeCount.
        where(customer_id: customer_id, cnpj: c.emitentes.first.documento, month: month, year: year).
        where(document_type: ['nfe', 'nfce', 'nfse', 'mde', 'cte']).sum(:document_count)
      if count > 0
        cnpj = c.emitentes.first.documento
        value = count * valor_unitario
        total_final += value
        r = Receivable.create(
          month: month,
          year: year,
          contract_id: c.id,
          customer_id: customer_id,
          status: 'open',
          value: value,
          description: "Indexação de #{count.to_s} documentos do CNPJ: #{cnpj}",
          is_setup_fee: false,
          is_adjustment: false,
          is_recurring: true
        )
        puts r.id
      else
        puts "Sem contagem para CNPJ #{cnpj}, contract id #{c.id.to_s}"
      end
      nil
    end
    if total_final < minimo_contratual
      Receivable.create(
        month: month,
        year: year,
        customer_id: customer_id,
        status: 'open',
        value: minimo_contratual - total_final,
        description: "Diferença para o mínimo contratual da indexação",
        is_setup_fee: false,
        is_adjustment: false,
        is_recurring: true 
      )
    end
  end

## CASO QUATRO
#Observar One Engenharia

#NFSeR nas prefeituras com webservices e NFe através de MDe. Proposta:
#- R$99,90 por CNPJ
#- NFSeR nas prefeituras já integradas e MDe#
#- Pacote com 500 notas
#- R$0,10 por nota adicional
#- R$495,00 para caixa de email
#- R$199,00 para implementação de novas cidades

#https://capivara.focusnfe.com.br/admin/financeiro/clientes/2189196
