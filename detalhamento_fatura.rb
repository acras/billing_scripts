def extrai_informacoes_fatura_cliente(customer_id, month, year)
  i2 = Saas::Invoice2.new
  puts ["Nome","CNPJ/CPF","I.E.","Usa NFe","Qtd. NFe", "Usa NFCe","Qtd. NFCe", "Usa NFSe","Qtd. NFSe", "Usa MDe","Qtd. MDe"].join(',')
  recs = Receivable.where(customer_id: customer_id, month: month, year: year, status: ['open','paid'])
  recs.each do |r|
    e = r.contract.emitentes.first
    s = ["\"#{e.nome}\"",e.documento,e.inscricao_estadual]
    enabled_docs = i2.get_enabled_docs_for_cnpjs(e.documento)
    counts = SaasDfeCount.where(year: 2025, month: 1, customer_id: customer_id, cnpj: e.documento).all
    s << enabled_docs[:nfe]
    s << counts.where(document_type: 'nfe').first.try(:document_count).to_i
    s << enabled_docs[:nfce]
    s << counts.where(document_type: 'nfce').first.try(:document_count).to_i
    s << enabled_docs[:nfse]
    s << counts.where(document_type: 'nfse').first.try(:document_count).to_i
    s << enabled_docs[:mde]
    s << counts.where(document_type: 'mde').first.try(:document_count).to_i
    s << r.value.to_s
    puts s.join(',')
  end
  nil
end

extrai_informacoes_fatura_cliente(988765, 11, 2024)
