MIN_NFE_ID =          310_000_000 # 2025-07-23
MIN_NFCOM_ID =                  0
MIN_RPS_ID =          178_200_000 # 2025-07-23
MIN_LOTE_RPS_ID =     182_000_000 # 2025-07-23
MIN_CTE_ID =           60_200_000 # 2025-07-23
MIN_DFE_ID =          167_300_000 # 2025-07-23
MIN_NFSER_ID =            604_000 # 2025-07-23
MIN_CFE_ID  =           3_452_000 # 2025-07-23
MIN_DOC_ORIGINAL_ID = 693_100_000 # 2025-07-23

      


def get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids)
  sql = <<-EOS
   select
    count(1) as total
    from
      notas_fiscais nf
      join documentos_originais do
        on do.id=nf.documento_original_id
      where do.empresa_id in (#{empresas.collect(&:id).join(',')}) and nf.created_at >= '#{dtinicial}'
        and nf.created_at < '#{dtfinal}'
        and nf.id > #{MIN_NFE_ID}
        and do.id > #{MIN_DOC_ORIGINAL_ID}
        and codigo_status=100
        and do.client_app_id in (#{client_app_ids.join(',')})
        and nf.modelo <> '65';
  EOS

  fatinfo = NotaFiscal.find_by_sql(sql)
  res = { total: 0 }
  f=fatinfo.first
  if f
    res = {
      total: f["total"].to_i
    }
  end

  res
end

def get_info_nfse_json(empresas, dtinicial, dtfinal, client_app_ids)
  #notas de serviço
  sql = <<-EOS
    select
      count(1) as total
    from
      rps r
    join documentos_originais do
      on do.id=r.documento_original_id
    where r.empresa_id in (#{empresas.collect(&:id).join(',')})
    and do.id > #{MIN_DOC_ORIGINAL_ID}
    and r.id > #{MIN_RPS_ID}
    and r.created_at >= '#{dtinicial}'
    and r.created_at < '#{dtfinal}'
    and r.codigo_verificacao is not null
    and do.client_app_id in (#{client_app_ids.join(',')});
  EOS
  fatinfo = Rps.find_by_sql(sql)
  f=fatinfo.first
  res = { total: 0 }
  if f
    res = {
      total: f["total"].to_i
    }
  end
  res
end

def get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids)
  sql = <<-EOS
   select
    count(1) as total
    from
      notas_fiscais nf
      join documentos_originais do
        on do.id=nf.documento_original_id
      where do.empresa_id in (#{empresas.collect(&:id).join(',')}) and nf.created_at >= '#{dtinicial}'
        and do.id > #{MIN_DOC_ORIGINAL_ID}
        and nf.created_at < '#{dtfinal}'
        and nf.id > #{MIN_NFE_ID}
        and codigo_status=100
        and do.client_app_id in (#{client_app_ids.join(',')})
        and nf.modelo = '65';
  EOS

  fatinfo = NotaFiscal.find_by_sql(sql)
  f=fatinfo.first
  res = { total: 0 }
  if f
    res = {
      total: f["total"].to_i
    }
  end
  res
end

def get_info_mde_json(empresas, dtinicial, dtfinal, client_app_ids)
  focus2 = ClientApp.where(name: 'Focus V2').first
  console = ClientApp.where(name: 'Script console').first
  client_app_ids_efetivos = client_app_ids - [focus2.id, console.id]
  empresa_ids = ClientAppEmpresa.where(empresa_id: empresas.pluck(:id), client_app_id: client_app_ids_efetivos).pluck(:empresa_id)
  # por algum bug no faturamento do backend, pode acontecer de ser feita contagem para client_apps que não tem
  # associação com a empresa
  if empresa_ids.empty?
    return {
      'ctes_total' => 0,
      'nfes_total' => 0,
      'nfes_completas' => 0
    }
  end

  #retornar as informações de recebimento de MDe contendo o total na primeira linhas
  sql = <<-EOS
    select type, count(*) as count
    from documentos_fiscais df
    inner join ambientes_emissao ae on (ae.id = df.ambiente_manifesto_id)
    where df.type in ('DocumentoFiscalNfe', 'DocumentoFiscalResumoNfe', 'DocumentoFiscalCte')
    and df.empresa_id in (#{empresa_ids.join(',')})
    and df.created_at >= '#{dtinicial}' and df.created_at < '#{dtfinal}'
    and df.id > #{MIN_DFE_ID}
    and ae.rails_env = 'production'
    group by type
  EOS
  fatinfo = {}
  DocumentoFiscal.find_by_sql(sql).each{|row| fatinfo[row['type']] = row['count'] }
  fatinfo['DocumentoFiscalNfe'] ||= 0
  fatinfo['DocumentoFiscalResumoNfe'] ||= 0
  fatinfo['DocumentoFiscalCte'] ||= 0
  {
    'ctes_total' => fatinfo['DocumentoFiscalCte'].to_i,
    'nfes_total' => fatinfo['DocumentoFiscalResumoNfe'].to_i,
    'nfes_completas' => fatinfo['DocumentoFiscalNfe'].to_i
  }
end

dtinicial = '2026-1-25'
dtfinal = '2026-2-25'


#  34292439000157
empresas = [Empresa.find(34508)]
client_app_ids = [75603]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#  29105730000139
empresas = [Empresa.find(9441)]
client_app_ids = [16692]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#  51125130000191
empresas = [Empresa.find(50110)]
dtinicial = '2024-11-25'
dtfinal = '2024-12-25'
client_app_ids = [111890]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# 05521261000170
empresas = [Empresa.find(75578)]
client_app_ids = [9169]
b=Benchmark.measure { puts get_info_nfse_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# 22110117000160
empresas = [Empresa.find(9441)]
client_app_ids = [16692]
b=Benchmark.measure { puts get_info_nfse_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# Psicomanager 43605953000196
empresas = [Empresa.find(72697)]
dtinicial = '2025-05-25'
dtfinal = '2025-06-25'
client_app_ids = [71118]
b=Benchmark.measure { puts get_info_nfse_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# Manafix 42219801000192
empresas = [Empresa.find(15805)]
dtinicial = '2024-06-25'
dtfinal = '2024-07-25'
client_app_ids = [32715]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# nutricar 21590391000111
empresas = [Empresa.find(10936)]
dtinicial = '2024-10-25'
dtfinal = '2024-11-25'
client_app_ids = [21653]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# 36282977000196
empresas = [Empresa.find(10936)]
dtinicial = '2024-08-25'
dtfinal = '2024-09-25'
client_app_ids = [21653]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# MARCOS PAULO BAGATIN 02760217973
empresas = Empresa.where(id: [20413, 21696, 44239])
dtinicial = '2024-08-25'
dtfinal = '2024-09-25'
client_app_ids = [42605, 45723, 98221]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


#Smart Damha 42676606000191
empresas = [Empresa.find(21529)]
client_app_ids = [45316]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# smartbreak 30782083000260
empresas = [Empresa.find(34809)]
client_app_ids = [76305]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# vendperto 32704335000187
empresas = [Empresa.find(15676)]
dtinicial = '2023-09-25'
dtfinal = '2023-10-25'
client_app_ids = [32420]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# mercadominio 28165341000136
empresas = [Empresa.find(14882)]
dtinicial = '2025-05-25'
dtfinal = '2025-06-25'
client_app_ids = [30625]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# Burger 20120709000480
empresas = [Empresa.find(19558)]
dtinicial = '2025-05-25'
dtfinal = '2025-06-25'
client_app_ids = [37029]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }



# vendinha 24 h 37462241000162
  empresas = [Empresa.find(43858)]
dtinicial = '2023-12-25'
dtfinal = '2024-01-25'
client_app_ids = [97220]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# RESPONSA - DO BAR A COZINHA 47794116000103
  empresas = [Empresa.find(32815)]
dtinicial = '2023-12-25'
dtfinal = '2024-01-25'
client_app_ids = [37029]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# expresso foods 43060772000121
empresas = [Empresa.find(19581)]
dtinicial = '2023-08-25'
dtfinal = '2023-09-25'
client_app_ids = [40759]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


# pep comercio ltda 33903366000200
empresas = [Empresa.find(20523)]
dtinicial = '2025-02-25'
dtfinal = '2025-03-25'
client_app_ids = [42862]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# marajó grande belem 10505190000152
empresas = [Empresa.find(22382)]
dtinicial = '2023-08-25'
dtfinal = '2023-09-25'
client_app_ids = [47202]
#b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }



# lifebox
empresas = [Empresa.find(18143)]
dtinicial = '2023-05-25'
dtfinal = '2023-06-25'
client_app_ids = [37029]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# R A TOMAZ
empresas = [Empresa.find(27962)]
dtinicial = '2023-05-25'
dtfinal = '2023-06-25'
client_app_ids = [61258]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Deconey
empresa_id = 15236
empresas = [Empresa.find(empresa_id)]
dtinicial = '2023-06-25'
dtfinal = '2023-07-25'
client_app_ids = [31437]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

# BURGER CHEF LTDA 32886379000175
empresa_id = 23342
empresas = [Empresa.find(empresa_id)]
dtinicial = '2023-09-25'
dtfinal = '2023-10-25'
client_app_ids = [37029]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


#Marajó 05443159000102
empresa_id = 17704
empresas = [Empresa.find(empresa_id)]
dtinicial = '2024-10-25'
dtfinal = '2024-11-25'
client_app_ids = [36632]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Dalle Ribeiro Griebler 05286224555
empresa_id = 15072
empresas = [Empresa.find(empresa_id)]
client_app_ids = [31054]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_mde_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


#FIVE ITABUNA BAR E RESTAURANTE LTDA 41646065000196
empresas = [Empresa.find(70904)]
client_app_ids = [153880, 24005]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_mde_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Jardins Cafe 51420473000189 
empresas = [Empresa.find(123108)]
client_app_ids = [259840, 24005]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_mde_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#THE DEW 35266153000160
empresas = [Empresa.find(36363)]
client_app_ids = [79963, 37029]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_mde_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#MARAJO REDENCAO 48118728000149
empresas = [Empresa.find(98663)]
client_app_ids = [36575, 210326]
b=Benchmark.measure { puts get_info_nfce_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Filial - Vg Grande Paulista/SP 00242184000791
empresas = [Empresa.find(51131)]
client_app_ids = [114090, 75702]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Docol 75339051000141
empresas = [Empresa.find(38694)]
client_app_ids = [85688, 83576]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }


#Mais provedor de serviços 06031381000152
empresas = [Empresa.find(25498)]
client_app_ids = [54596, 54173]
b=Benchmark.measure { puts get_info_nfse_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

#Leste gas comercio 38403555000157
empresas = [Empresa.find(86058)]
client_app_ids = [184805, 21431]
b=Benchmark.measure { puts get_info_nfe_json(empresas, dtinicial, dtfinal, client_app_ids).inspect }

