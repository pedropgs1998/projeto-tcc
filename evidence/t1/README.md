# Evidências experimentais — T1 / M1

## Estado experimental

O estado T1 corresponde à aplicação da mudança M1 sobre o baseline T0.

A mudança introduz a fonte de pagamentos:

`raw.order_payments`

Grão da fonte:

`(order_id, payment_sequential)`

A relação entre pedidos e pagamentos é 1:N.

## Profiling da nova fonte

Foram identificados:

- 103886 registros de pagamento;
- 99440 pedidos com pagamento;
- nenhuma duplicidade no grão `(order_id, payment_sequential)`;
- nenhum pagamento associado a pedido inexistente;
- 1 pedido sem pagamento;
- até 29 registros de pagamento por pedido;
- 2961 pedidos com múltiplos registros de pagamento;
- 2246 pedidos com múltiplos tipos de pagamento;
- valor total registrado de 16008872.12.

O único pedido sem pagamento possui status `delivered`.

A ausência de pagamento foi preservada como NULL nas métricas relacionadas a pagamento, sem remover o pedido da população analítica previamente definida.

## Reconciliação

Entre os pedidos presentes nas fontes de itens e pagamentos:

- 98665 possuem itens e pagamento;
- 98362 apresentam diferença de até R$ 0,01;
- 303 apresentam diferença superior a R$ 0,01;
- a maior diferença encontrada foi de R$ 182,81.

As diferenças foram preservadas, pois `valor_calculado_pedido` e `valor_pago_pedido` representam conceitos distintos.

## Kimball

Foi adicionada:

`kimball.fact_payment`

Grão:

`(order_id, payment_sequential)`

Os pagamentos são agregados por pedido antes da combinação com outras métricas, evitando fan-out entre as relações ORDER 1:N ITEM e ORDER 1:N PAYMENT.

## Data Vault 2.0

Foi adicionado:

`data_vault.sat_order_payment`

O objeto foi modelado como Multi-Active Satellite associado ao `hub_order`.

`payment_sequential` é utilizado como discriminador dos múltiplos pagamentos pertencentes ao mesmo pedido.

## Data Mart

Foi adicionada:

`data_mart.fact_payment`

O Data Mart mantém contrato dimensional equivalente ao Kimball, porém sua carga é derivada do Data Vault.

## Impacto analítico

### Q1

Sem alteração.

Resultado:

`13221498.11`

### Q2

Foi adicionada a métrica:

`ticket_medio_pago`

Resultados:

- ticket médio calculado: `159.8268387611683493`;
- ticket médio pago: `159.8563571628471035`.

### Q3

Foram adicionadas:

- `valor_pago`;
- `ticket_medio_pago`.

A granularidade permanece ano + mês + UF do cliente.

Foram produzidos 556 grupos em ambas as arquiteturas.

## Equivalência

Após M1:

- diferença Q1: 0;
- diferença do ticket médio calculado: 0;
- diferença do ticket médio pago: 0;
- grupos Q3 no Kimball: 556;
- grupos Q3 no Data Mart: 556;
- grupos ausentes: 0;
- grupos com diferenças de conteúdo: 0.

As duas implementações permanecem funcionalmente equivalentes no estado T1.