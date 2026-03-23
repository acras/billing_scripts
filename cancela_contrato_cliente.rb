def cancela_contrato_cliente(customer_id, motivo)
  Lancamento.where(person_id: customer_id, status: 'pendente').all.each {|l| l.cancel!}
  Contract.where(customer_id: customer_id, status: [Contract::Status::Active, Contract::Status::Started]).each do |contract|
    last_date = Receivable.where(contract_id: contract.id, status: 'paid').maximum(:actual_date)
    if last_date
      contract.status = Contract::Status::Canceled
      contract.active_to = last_date
      contract.cancel_motive = motivo
      contract.save
    else
      contract.status = Contract::Status::Sale_Failed
      contract.save
    end
  end
end
