# Evidências do Estado T2

Este diretório reúne as evidências geradas para o estado T2 do experimento.

T2 corresponde à aplicação da mudança M2 sobre o estado T1 já validado.

A mudança M2 introduz dois atributos temporais já existentes na fonte `raw.orders`:

- `order_approved_at`
- `order_delivered_carrier_date`

Esses atributos passam a ser utilizados para calcular novas métricas temporais na consulta analítica Q3.

---

## Objetivo de M2

M2 foi definida para avaliar o impacto da inclusão de novos atributos em uma entidade já existente.

Diferentemente de M1, não há introdução de uma nova fonte nem alteração da granularidade dos dados.

A mudança exige a propagação dos novos atributos pelas duas trajetórias avaliadas:

```text
Kimball:
raw
→ fact_order
→ consultas analíticas

Data Vault:
raw
→ sat_order
→ Data Mart
→ consultas analíticas
```

As consultas Q1 e Q2 permanecem funcionalmente inalteradas.

A consulta Q3 passa a incluir:

```text
media_horas_aprovacao
media_horas_preparacao
media_horas_transporte
```

---

## Atributos adicionados

Os seguintes atributos foram incorporados em T2:

```text
order_approved_at
order_delivered_carrier_date
```

No modelo Kimball, foram adicionados em:

```text
kimball.fact_order
```

No Data Vault, foram adicionados em:

```text
data_vault.sat_order
```

No Data Mart derivado do Data Vault, foram adicionados em:

```text
data_mart.fact_order
```

Nenhuma nova tabela foi criada em M2.

---

## Tratamento dos atributos temporais

Os dados originais não foram corrigidos ou alterados para eliminar inconsistências temporais.

Cada métrica considera apenas os registros semanticamente válidos para o respectivo cálculo.

### Tempo de aprovação

O tempo de aprovação é calculado quando:

```text
order_purchase_timestamp IS NOT NULL
order_approved_at IS NOT NULL
order_approved_at >= order_purchase_timestamp
```

O cálculo utilizado é:

```text
order_approved_at - order_purchase_timestamp
```

---

### Tempo de preparação

O tempo de preparação é calculado quando:

```text
order_approved_at IS NOT NULL
order_delivered_carrier_date IS NOT NULL
order_delivered_carrier_date >= order_approved_at
```

O cálculo utilizado é:

```text
order_delivered_carrier_date - order_approved_at
```

---

### Tempo de transporte

O tempo de transporte é calculado quando:

```text
order_delivered_carrier_date IS NOT NULL
order_delivered_customer_date IS NOT NULL
order_delivered_customer_date >= order_delivered_carrier_date
```

O cálculo utilizado é:

```text
order_delivered_customer_date - order_delivered_carrier_date
```

Os intervalos são convertidos para horas por meio de:

```sql
EXTRACT(EPOCH FROM intervalo) / 3600.0
```

---

## Profiling de M2

O profiling dos atributos temporais foi executado antes da implementação da mudança.

Arquivo:

```text
profile/profile_m2.txt
```

Foram identificados:

```text
Total de pedidos: 99.441
Pedidos delivered: 96.478
```

Valores nulos na população completa:

```text
order_purchase_timestamp: 0
order_approved_at: 160
order_delivered_carrier_date: 1.783
order_delivered_customer_date: 2.965
```

Valores nulos entre pedidos com status `delivered`:

```text
order_purchase_timestamp: 0
order_approved_at: 14
order_delivered_carrier_date: 2
order_delivered_customer_date: 8
```

Pedidos entregues com todos os timestamps disponíveis:

```text
96.455
```

Também foram identificadas inconsistências temporais:

```text
Aprovação anterior à compra: 0

Entrega à transportadora anterior à aprovação:
1.350

Entrega ao cliente anterior à transportadora:
23

Entrega ao cliente anterior à compra:
0
```

Por esse motivo, os indicadores são calculados de forma independente.

As populações válidas ficaram em:

```text
Tempo de aprovação:
96.464 registros

Tempo de preparação:
95.112 registros

Tempo de transporte:
96.446 registros
```

As médias observadas foram:

```text
Tempo médio de aprovação:
10,27676701210353661009 horas

Tempo médio de preparação:
68,48196300151400454192 horas

Tempo médio de transporte:
223,99924012746338192683 horas
```

Aproximadamente:

```text
Aprovação: 10,28 horas
Preparação: 68,48 horas
Transporte: 224,00 horas
```

---

## Alteração no modelo Kimball

A tabela alterada foi:

```text
kimball.fact_order
```

Foram adicionadas duas colunas:

```text
order_approved_at
order_delivered_carrier_date
```

Os valores são carregados diretamente a partir de:

```text
raw.orders
```

A granularidade da tabela permanece:

```text
uma linha por order_id
```

A validação final confirmou:

```text
fact_order:
99.441 registros

order_approved_at nulo:
160

order_delivered_carrier_date nulo:
1.783

registros divergentes em relação à raw:
0

pedidos da raw ausentes na fact_order:
0
```

Arquivo de evidência:

```text
validation/validate_kimball_t2.txt
```

---

## Alteração no Data Vault

A estrutura alterada foi:

```text
data_vault.sat_order
```

Foram adicionadas duas colunas:

```text
order_approved_at
order_delivered_carrier_date
```

Não foi criado um novo Satellite.

Os novos atributos foram incorporados ao `sat_order` existente porque:

- possuem a mesma origem dos demais atributos de pedido;
- pertencem ao mesmo contexto funcional;
- utilizam o mesmo Hub;
- não possuem processo de carga independente.

A inclusão dos atributos também exigiu a atualização da lógica de cálculo do:

```text
hashdiff
```

O `hashdiff` de T2 passou a considerar:

```text
order_status
order_purchase_timestamp
order_approved_at
order_delivered_carrier_date
order_delivered_customer_date
order_estimated_delivery_date
```

O `load_timestamp` existente não foi alterado durante o backfill de M2.

A mudança representa uma evolução controlada da estrutura, e não a chegada de uma nova versão de negócio do pedido.

A validação final confirmou:

```text
sat_order:
99.441 registros

orders distintos:
99.441

order_approved_at nulo:
160

order_delivered_carrier_date nulo:
1.783

referências inválidas:
0

registros divergentes:
0

pedidos da raw ausentes:
0

hashdiffs inconsistentes:
0
```

Arquivo de evidência:

```text
validation/validate_data_vault_t2.txt
```

---

## Alteração no Data Mart

A tabela alterada foi:

```text
data_mart.fact_order
```

Foram adicionadas:

```text
order_approved_at
order_delivered_carrier_date
```

Os atributos são carregados a partir do Data Vault:

```text
data_vault.hub_order
data_vault.sat_order
```

A camada `raw` não participa diretamente da carga do Data Mart.

A validação final confirmou:

```text
fact_order:
99.441 registros

order_approved_at nulo:
160

order_delivered_carrier_date nulo:
1.783

registros divergentes em relação ao Data Vault:
0

registros divergentes em relação ao Kimball:
0

pedidos do Vault ausentes no Data Mart:
0
```

As populações válidas foram:

```text
Tempo de aprovação:
96.464

Tempo de preparação:
95.112

Tempo de transporte:
96.446
```

Arquivo de evidência:

```text
validation/validate_data_mart_t2.txt
```

---

## Consultas analíticas

As consultas Q1 e Q2 foram preservadas.

### Q1

Q1 continua calculando o valor bruto dos itens de pedidos entregues.

Resultado:

```text
Kimball:
13.221.498,11

Data Mart:
13.221.498,11

Diferença:
0,00
```

---

### Q2

O ticket médio calculado permaneceu:

```text
Kimball:
159,8268387611683493

Data Mart:
159,8268387611683493

Diferença:
0
```

O ticket médio pago permaneceu:

```text
Kimball:
159,8563571628471035

Data Mart:
159,8563571628471035

Diferença:
0
```

---

### Q3

Q3 foi alterada para incluir:

```text
media_horas_aprovacao
media_horas_preparacao
media_horas_transporte
```

A consulta continua agrupando os resultados por:

```text
ano
mês
estado do cliente
```

A validação de equivalência apresentou:

```text
Grupos Kimball:
556

Grupos Data Mart:
556

Grupos existentes no Kimball e ausentes no Data Mart:
0

Grupos existentes no Data Mart e ausentes no Kimball:
0

Grupos com diferenças nas métricas temporais:
0

Grupos com qualquer diferença:
0
```

Arquivo:

```text
validation/validate_t2_equivalence.txt
```

---

## Impacto estrutural T1 → T2

O estado estrutural de T2 ficou:

```text
Kimball:
8 tabelas
64 colunas
8 PKs
13 FKs

Data Vault:
12 tabelas
72 colunas
12 PKs
11 FKs

Data Mart:
8 tabelas
64 colunas
8 PKs
13 FKs
```

Em T1, os totais eram:

```text
Kimball:
8 tabelas
62 colunas

Data Vault:
12 tabelas
70 colunas

Data Mart:
8 tabelas
62 colunas
```

Portanto, M2 produziu:

```text
Kimball:
0 novas tabelas
2 novas colunas
0 novas PKs
0 novas FKs

Data Vault:
0 novas tabelas
2 novas colunas
0 novas PKs
0 novas FKs

Data Mart:
0 novas tabelas
2 novas colunas
0 novas PKs
0 novas FKs
```

---

## Impacto operacional

O impacto controlado de M2 foi registrado da seguinte forma.

### Kimball

```text
Tabelas adicionadas:
0

Tabelas alteradas:
1

Colunas adicionadas:
2

PKs adicionadas:
0

FKs adicionadas:
0

Rotinas de carga alteradas:
1

Consultas analíticas alteradas:
1

Lógicas de hashdiff alteradas:
0
```

### Data Vault

```text
Tabelas adicionadas:
0

Tabelas alteradas:
1

Colunas adicionadas:
2

PKs adicionadas:
0

FKs adicionadas:
0

Rotinas de carga alteradas:
1

Consultas analíticas alteradas diretamente:
0

Lógicas de hashdiff alteradas:
1
```

### Data Mart

```text
Tabelas adicionadas:
0

Tabelas alteradas:
1

Colunas adicionadas:
2

PKs adicionadas:
0

FKs adicionadas:
0

Rotinas de carga alteradas:
1

Consultas analíticas alteradas:
1

Lógicas de hashdiff alteradas:
0
```

Arquivo:

```text
metrics/impact_t1_t2.txt
```

---

## Reprodutibilidade

T2 pode ser reconstruído a partir de ambiente limpo por meio de:

```bash
./scripts/rebuild_t2.sh
```

O fluxo executado é:

```text
ambiente limpo
→ T0
→ M1
→ T1
→ M2
→ T2
```

O script:

1. reconstrói T0;
2. aplica M1;
3. valida T1;
4. aplica M2 no Kimball;
5. aplica M2 no Data Vault;
6. aplica M2 no Data Mart;
7. valida individualmente as três camadas;
8. valida a equivalência analítica de T2.

A execução final validada iniciou em:

```text
2026-09-27 21:17:36
```

e terminou em:

```text
2026-09-27 21:21:22
```

O estado T2 foi reconstruído e validado com sucesso.

Arquivo:

```text
logs/rebuild_t2.log
```

---

## Otimização da reconstrução do Data Mart

Durante os testes de reprodutibilidade foi identificado um plano de execução inadequado durante a reconstrução de:

```text
data_mart.fact_order_item
```

A execução apresentava tempo significativamente superior ao observado anteriormente.

Para garantir estatísticas atualizadas antes da construção das tabelas fato do Data Mart, a carga passou a executar explicitamente:

```text
ANALYZE
```

sobre as estruturas envolvidas.

Também foram utilizados parâmetros de sessão específicos para a carga:

```text
work_mem = 128MB
random_page_cost = 1.1
```

Esses ajustes afetam apenas a otimização da execução e não alteram:

- os dados;
- a estrutura lógica dos modelos;
- as regras de negócio;
- as métricas analíticas;
- a comparação entre as arquiteturas.

Após a alteração, a reconstrução voltou a ser concluída em poucos minutos.

---

## Coleta de evidências

Depois da reconstrução, todas as evidências de T2 podem ser regeneradas por:

```bash
./scripts/collect_t2_evidence.sh
```

A coleta final foi concluída com sucesso.

Arquivo:

```text
logs/collect_t2_evidence.log
```

---

## Estrutura das evidências

```text
evidence/t2/
├── README.md
├── environment/
│   ├── database_objects_t2.txt
│   ├── docker_versions.txt
│   ├── git_state.txt
│   └── postgres_version.txt
├── logs/
│   ├── collect_t2_evidence.log
│   └── rebuild_t2.log
├── metrics/
│   └── impact_t1_t2.txt
├── profile/
│   └── profile_m2.txt
├── queries/
│   ├── queries_data_mart_t2.txt
│   └── queries_kimball_t2.txt
└── validation/
    ├── validate_data_mart_t2.txt
    ├── validate_data_vault_t2.txt
    ├── validate_kimball_t2.txt
    └── validate_t2_equivalence.txt
```

---

## Estado final de T2

O estado T2 foi considerado concluído após:

```text
profiling de M2
+
alteração do modelo Kimball
+
alteração do Data Vault
+
alteração do Data Mart
+
validação individual das estruturas
+
validação dos hashdiffs
+
validação das populações temporais
+
validação de equivalência analítica
+
medição do impacto T1 → T2
+
rebuild completo a partir de ambiente limpo
+
regeneração das evidências
```

Os resultados confirmaram equivalência funcional entre o modelo dimensional Kimball e o Data Mart derivado do Data Vault no estado T2.

O próximo estado do experimento será M3/T3, relacionado à introdução controlada de histórico de categoria de produto.