#este pequeno procedimento serve para verificar se todos os CNPJs que utilizaram nosso
#sistema no mês/ano possuem uma contagem de notas neste mesmo mês
#se possui a contagem será cobrado, senão não.


#dar load desse arquivo e rodar audit_counts. Copiar e colar a saída em uma planilha para termos a estatística de quantas notas
#foram recuperadas e ver casos não cobertos. 

#Se der erro na execução, copiar e colar na planilha e rodar de novo o script com o parâmetro skip.

def audit_counts(month, year, skip: 0)
  load "lib/billing_query_usage_records.rb"
  client = BillingQueryUsageRecords.new
  all_records = client.all_records(month: month, year: year)
  total = all_records.size
  puts "Total de registros encontrados: #{total}"
  if skip > 0
    puts "Pulando os primeiros #{skip} registros"
  end
  keys = ["cnpj","tipo_doc","emitente_id","customer_id","contract_id","contract_status","contract_active_from","new_document_count","obs"]
  puts keys.join(',')
  current = 0
  all_records.each do |r|
    current += 1
    if current <= skip
      next
    end
    print "\r#{current}/#{total}"
    cnpj = r['cnpj']
    document_type = r['doc_type']
    count = SaasDfeCount.where(month: month, year: year, cnpj: cnpj, document_type: document_type).sum(:document_count)
    if count == 0
      info = analisa_cnpj_sem_contagem(cnpj, document_type, month, year)
      puts "\r#{keys.map { |key| info[key.to_sym] }.join(',')}" if info
    end
  end
  nil
end

#vai retornar nil se estiver tudo ok, info se tiver que logar
def analisa_cnpj_sem_contagem(cnpj, tipo_doc, month, year)
  deve_logar = true
  info = {cnpj: cnpj, tipo_doc: tipo_doc}
  e = Emitente.where("cnpj = :cnpj OR cpf = :cpf", cnpj: cnpj, cpf: cnpj)
  if e.count == 0
    lida_sem_emitente(info, cnpj, tipo_doc, month, year)
  elsif e.count == 1
    emitente = e.first
    info[:emitente_id] = emitente.id
    contract = e.first.contract
    if contract
      info[:customer_id] = contract.customer.id
      info[:contract_id] = contract.id
      info[:contract_status] = contract.status
      info[:contract_active_from] = contract.active_from
      #se este contrato está como started...
      if contract.status == 'S'
        deve_logar = lida_com_contrato_started(info, contract, cnpj, tipo_doc, month, year)
      elsif contract.status == 'F'
        lida_com_emitente_com_contrato_falhou_venda(info, e.first, contract, tipo_doc, month, year)
      elsif contract.status == 'C'
        deve_logar = lida_com_emitente_com_contrato_cancelado(info, e.first, contract, tipo_doc, month, year)
      end
    else
      lida_com_emitente_sem_contrato(info, emitente, tipo_doc, month, year)
    end
  else #mais de um emitente
    lida_com_multiplos_emitentes(info, cnpj, e, tipo_doc, month, year)
  end
  deve_logar ? info : nil
end

def lida_com_emitente_com_contrato_cancelado(info, emitente, contract, tipo_doc, month, year)
  deve_logar = true
  cliente_tem_outros_contratos_ativos_ou_started = Contract.where(customer_id: contract.customer_id, status: ['A','S']).any?
  if cliente_tem_outros_contratos_ativos_ou_started  
    if Receivable.where(contract_id: contract.id, status: 'paid').any?
      contract.status = 'A'
    else
      contract.status = 'S'
    end
    contract.save
    recontagem(info, contract.id, emitente.documento, tipo_doc, month, year)
  end
  deve_logar
end

#retorna true se for pra logar, false se estiver tudo certo
def lida_com_contrato_started(info, contract, cnpj, tipo_doc, month, year)
  deve_logar = true
  # ... e está marcado para iniciar no futuro
  if contract.active_from > Date.today
    # ... e ainda por cima o mesmo cliete tem contratos já ativos ou marcados para iniciar no passado
    if Contract.where(customer_id: contract.customer_id, status: ['A','S']).
                where('active_from < :f', f: Date.today).count > 0
      # ... então este contrato não deveria iniciar no futuro, ajusta a data
      contract.active_from = Date.new(year, month)
      contract.save
      # ... e faz a recontagem
      recontagem(info, contract.id, cnpj, tipo_doc, month, year)
    else
      #mas se não tem ativo nem iniciando no passado, presumo que seja trial, tudo ok, não logar
      deve_logar = false
    end
  end
  deve_logar
end

def recontagem(info, contract_id, cnpj, tipo_doc, month, year)
  i2 = Saas::Invoice2.new
  SaasDfeCount.where(cnpj: cnpj, month: month, year: year, document_type: tipo_doc).where('document_count = 0').delete_all
  i2.count_month_documents_for_cnpj(contract_id, cnpj, month, year, true)
  new_count = SaasDfeCount.where(cnpj: cnpj, month: month, year: year, document_type: tipo_doc).first
  info[:obs] ||= ''
  if new_count
    info[:new_document_count] = new_count.document_count
    info[:obs] += " Recontagem considerou #{new_count.document_count} documentos"
  else
    info[:obs] += " Pediu recontagem porém segue sem documentos contados"
  end
end

def lida_com_multiplos_emitentes(info, cnpj, emitentes, tipo_doc, month, year)
  tem_contratos = emitentes.collect {|e| e.contract_id}.compact.count > 0
  if tem_contratos
    customer_ids = emitentes.collect {|e| e.contract.try(:customer_id)}.uniq.compact
    if customer_ids.count == 1
      customer_id = customer_ids.first
      info[:customer_id] = customer_id
      #agora sei que todos os emitentes são do mesmo cliente e tem contratos, devo procurar o melhor contrato pra alocar essa cobrança
      contract_ids = emitentes.collect {|e| e.contract_id}.compact 
      #primeira opção é achar um contrato ativo... pouco provável pois se assim fosse já teria contagem
      c = Contract.where(id: contract_ids, status: 'A').first
      if c
        recontagem(info, c.id, cnpj, tipo_doc, month, year)
      else
        #Se não achei um ativo procuro um Started
        c = Contract.where(id: contract_ids, status: 'S').first
        if c
          lida_com_contrato_started(info, c, cnpj, tipo_doc, month, year)
        else
          info[:emitente_id] = 'múltiplos'
          info[:obs] = "Emitentes possíveis: #{emitentes.collect{|ee| ee.id}.join(';')}, contratos do mesmo cliente mas nenhum active nem started"  
        end
      end
    else
      info[:emitente_id] = 'múltiplos'
      info[:obs] = "Emitentes possíveis: #{emitentes.collect{|ee| ee.id}.join(';')}, contratos com mais de um cliente"  
    end
  else
    info[:emitente_id] = 'múltiplos'
    info[:obs] = "Emitentes possíveis: #{emitentes.collect{|ee| ee.id}.join(';')}, nenhum con contrato"
  end
end

def lida_sem_emitente(info, cnpj, tipo_doc, month, year)
  #primeiro vou buscar no  GW as empresas com esse CNPJ
  empresas = AcrasNfe::Empresa.where(cnpj: cnpj).all
  if empresas.count == 0
    info[:obs] = 'ESTRANHO: Não tem empresa no Gateway; mas então de onde veio a informação de que tinha emissão?'
  elsif empresas.count == 1
    empresa = empresas.first
    emitente_pela_empresa = Emitente.where(acras_nfe_empresa_id: empresa.id)
    if emitente_pela_empresa.count == 1
      #ajustar o emitente para ter o CNPJ equivalente ao que está no gateway (assumo que o gw é a fonte da verdade')
      e = emitente_pela_empresa.first
      e.cnpj = cnpj
      e.save(validate: false) #perigoso mas necessário, é uma alteração que precisa ocorrer e não deveria precisar em primeiro lugar
      i2 = Saas::Invoice2.new
      i2.count_month_documents_for_cnpj(e.contract_id, cnpj, month, year)
      new_count = SaasDfeCount.where(cnpj: e.cnpj, month: month, year: year, document_type: tipo_doc).first
      if new_count
        info[:emitente_id] = e.id
        info[:contract_id] = e.contract_id
        info[:customer_id] = e.contract.customer_id
        info[:new_document_count] = new_count.document_count
        info[:obs] = "Recontagem considerou #{new_count.document_count} documentos"
      else
        info[:obs] = "Pediu recontagem porém segue sem documentos contados"
      end  
    elsif emitente_pela_empresa.count > 1
      info[:obs] = "AcrasNfe::Empresa.id == #{empresa.id.to_s}. emitente_ids: #{emitente_pela_empresa.collect {|e| e.id}.join(';')}" 
    else
      info[:obs] = "AcrasNfe::Empresa.id == #{empresa.id.to_s}. SEM Emitentes pela acras_nfe_empresa_id"  
    end
  else
    info[:obs] = "Múltiplas empresas no Gateway; ids: #{empresas.collect {|e| e.id}.join(';')}"
  end
end

def lida_com_emitente_sem_contrato(info, emitente, tipo_doc, month, year)
  #um emitente e sem contrato significa que o emitente pode estar ligado a um customer_id, tentar esse caminho
  customer_id = emitente.try(:domain).try(:customer_id)
  if customer_id
    info[:customer_id] = customer_id
    customer = Customer.find(customer_id)
    algum_contrato_ativo_ou_started = Contract.where(customer_id: customer_id, status: ['A', 'S']).any?
    if algum_contrato_ativo_ou_started
      data_inicio = Date.today.at_beginning_of_month
      c = Contract.create!(customer_id: customer_id, status: 'S', active_from: data_inicio, contract_type: 'DFE')
      obs = "customer_id inferido. Contrato criado com id #{c.id.to_s}."
      emitente.contract_id = c.id
      emitente.save
      #e tenta a nova contagem
      i2 = Saas::Invoice2.new
      i2.count_month_documents_for_cnpj(c.id, emitente.cnpj, month, year)
      new_count = SaasDfeCount.where(cnpj: emitente.cnpj, month: month, year: year, document_type: tipo_doc).first
      if new_count
        info[:new_document_count] = new_count.document_count
        info[:obs] = obs + "Recontagem considerou #{new_count.document_count} documentos"
      else
        info[:obs] = obs + "Pediu recontagem porém segue sem documentos contados"
      end 
    else
      info[:obs] = "customer_id inferido com base no emitente.domain.customer_id, porém sem viabilidade de criar contrato"
    end
    
  else
    info[:obs] = "Emitente não levou a um customer_id. emitente_id: #{emitente.id.to_s}. domain_id: #{emitente.try(:domain_id).to_s}"
  end
end


def lida_com_emitente_com_contrato_falhou_venda(info, emitente, contract, tipo_doc, month, year)
  #primeiro olhar para ver se este contrato tem recebimentos, se tiver, marca como ativo
  tem_recebimentos = Receivable.where(contract_id: contract.id, status: ['open','paid']).count > 0
  #e também olhar para ver se o cliente tem outros contratos ativos ou started
  cliente_tem_outros_contratos = Contract.where(customer_id: contract.customer_id, status: ['A','S']).count > 0
  if tem_recebimentos || cliente_tem_outros_contratos
    #se tem, então marca esse contrato como ativo
    contract.status = 'A'
    contract.save
    #e faz a recontagem
    i2 = Saas::Invoice2.new
    i2.count_month_documents_for_cnpj(contract.id, emitente.documento, month, year, true)
    new_count = SaasDfeCount.where(cnpj: emitente.documento, month: month, year: year, document_type: tipo_doc).first
    if new_count
      info[:new_document_count] = new_count.document_count
      info[:obs] = "Recontagem considerou #{new_count.document_count} documentos"
    else
      info[:obs] = "Pediu recontagem porém segue sem documentos contados"
    end
  else
    info[:obs] = "Não dá para reativar o contrato pois não tem recebimentos no contrato e o cliente não tem outros contratos ativos ou started "
  end
  info
end


# def lida_com_situacao_sem_emitente(cnpj, month, year)
#   #o resultado desta função é um array para complementar o que o 'analisa_cnpj_sem_contagem'
#   #retorna. Adiciona "sit. emitente", "customer_id", "status contrato", "ativo desde", "recuperados", "obs."
#   r = []
#   e = AcrasNfe::Empresa.where(cnpj: cnpj).all
#   if e.count == 0
#     r << "sem emitente e sem empresa"
#   elsif e.count == 1
#     reseller_ids = e.first.client_apps.collect {|ca| ca.id}
#     domains = Domain.where(reseller_id: reseller_ids).all
#     if domains.count == 0
#       r << "com empresa no gateway mas sem domain para o reseller"
#     elsif domains.count == 1
#       r << "encontrada empresa, e customer no backend"
#       domain = domains.first
#       customer = domain.customer
#       if customer
#         r << "encontrada empresa, encontrado domain, e customer no backend"
#         r << customer.id
        
#         c = Contract.create(customer_id: customer.id,
#                             status: 'A',
#                             active_from: Date.new(year, month),
#                             contract_type: 'DFE'
#                             )
#         e = Emitente.create(nome: e.razao_social,
#                             contract_id: c.id, 
#                             cnpj: cnpj, <<<
#                             cpf: cnpj, <<<
#                             domain_id: domain.id, 
#                             acras_nfe_empresa_id: e.first.id)
#         #rodar a contagem
#       else
#         r << "encontrada empresa, encontrado domain, mas sem customer no backend"
#       end
#     else
#       r << "com empresa no gateway e mais de um domain para o reseller"
#     end
#   else
#     r << "mais de uma empresa para o emitente no gateway"
#   end
  
# end

#verificação abaixo seria para bater TODOS os emitentes contra o CNPJ no gateway
#primeiro vamos tentar meios mais focados nos problemas que tivermos.
# def lida_com_emitentes_com_cnpj_errado
#   q = Emitente.where.not(acras_nfe_empresa_id: nil) 
#   total = q.count
#   current = 0
#   q.find_each do |e|
#     current += 1
#     print "\r#{current}/#{total}"
#     emp = AcrasNfe::Empresa.find(e.acras_nfe_empresa_id)
#     if emp.cnpj != e.cnpj
#       puts "\r#{e.id.to_s},#{e.cnpj.to_s},#{emp.cnpj.to_s}"
#     end
#   end
# end