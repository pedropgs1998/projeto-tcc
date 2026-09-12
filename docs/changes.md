# Mudanças Experimentais

## 1. Objetivo

Este documento define os cenários de evolução utilizados no experimento de comparação entre:

- Modelagem Dimensional de Kimball;
- Data Vault 2.0 com Data Mart dimensional para consumo analítico.

O estado inicial do ambiente é definido em `docs/baseline.md`.

A partir desse estado, três mudanças serão introduzidas sequencialmente:

1. M1 — inclusão de uma nova fonte de pagamentos;
2. M2 — disponibilização de novos atributos do ciclo logístico do pedido;
3. M3 — introdução de requisito de preservação histórica de categoria de produto.

O objetivo não é avaliar o conteúdo comercial do dataset Olist, mas observar como cada abordagem de modelagem precisa evoluir diante dos mesmos requisitos.

As duas implementações deverão receber:

- os mesmos dados;
- as mesmas mudanças;
- as mesmas regras de negócio;
- as mesmas consultas analíticas;
- as mesmas validações.

Nenhuma das arquiteturas deverá receber antecipadamente estruturas destinadas exclusivamente a requisitos que ainda não existem naquele estado do experimento.

---

# 2. Estratégia experimental

As mudanças serão aplicadas de forma acumulativa.

O sistema evolui da seguinte maneira:

T0 — Baseline
    |
    | M1 — Nova fonte de pagamentos
    v
T1 — Baseline + pagamentos
    |
    | M2 — Novos atributos do ciclo logístico
    v
T2 — Estado anterior + detalhamento logístico
    |
    | M3 — Preservação histórica
    v
T3 — Estado final

Cada estado representa a evolução do estado imediatamente anterior.

O impacto de cada mudança deverá ser medido pelo delta entre os dois estados envolvidos:

M1 = T1 - T0

M2 = T2 - T1

M3 = T3 - T2

Dessa forma, estruturas introduzidas por mudanças anteriores continuam fazendo parte do sistema, mas não deverão ser contabilizadas novamente como impacto das mudanças seguintes.

Exemplo:

Se uma tabela foi criada em M1 e permanece inalterada em M2, sua existência não será contabilizada como alteração provocada por M2.

---

# 3. Regras gerais de execução

Para todas as mudanças deverão ser respeitadas as seguintes regras:

1. Os dados originais da camada `raw` deverão ser preservados.

2. A camada `raw` é comum às duas abordagens e não faz parte da comparação estrutural entre Kimball e Data Vault.

3. As duas arquiteturas deverão receber exatamente a mesma mudança.

4. As mesmas regras de negócio deverão ser utilizadas nas duas implementações.

5. Resultados analíticos deverão ser funcionalmente equivalentes.

6. Diferenças de resultados deverão ser investigadas antes de qualquer conclusão sobre as arquiteturas.

7. Alterações realizadas apenas para facilitar uma das arquiteturas não serão permitidas.

8. Cada mudança deverá registrar quais objetos foram criados, alterados ou reprocessados.

9. As mudanças deverão ser implementadas apenas quando o estado anterior estiver funcionalmente validado.

---

# 4. Estado inicial — T0

O estado inicial é definido no documento:

`docs/baseline.md`

Fontes analíticas disponíveis:

- customers;
- orders;
- order_items;
- products;
- sellers.

Consultas existentes:

- Q1 — Valor bruto dos itens vendidos;
- Q2 — Ticket médio calculado dos pedidos;
- Q3 — Relatório mensal de desempenho por UF.

Fontes ainda indisponíveis analiticamente:

- order_payments;
- order_reviews;
- geolocation;
- product_category_translation.

Os atributos que serão introduzidos posteriormente pela M2 também deverão ser considerados indisponíveis para a modelagem analítica inicial, mesmo estando presentes fisicamente na fonte original.

---

# 5. M1 — Inclusão de uma nova fonte de pagamentos

## 5.1 Objetivo

Avaliar o impacto da incorporação de uma nova fonte com granularidade própria e relação 1:N com uma entidade já existente.

A mudança também deverá avaliar o efeito dessa nova informação sobre consultas analíticas previamente implementadas.

---

## 5.2 Estado anterior

Em T0, não existe informação analítica sobre os pagamentos efetivamente registrados para os pedidos.

O valor de um pedido é calculado utilizando:

valor_calculado_pedido =
SUM(price + freight_value)
GROUP BY order_id

Esse valor representa uma medida calculada a partir dos itens e do frete.

Ele não deverá ser tratado como valor efetivamente pago.

---

## 5.3 Nova fonte

Em T1 passa a estar disponível:

`raw.order_payments`

Fonte original:

`olist_order_payments_dataset.csv`

Campos:

- order_id;
- payment_sequential;
- payment_type;
- payment_installments;
- payment_value.

---

## 5.4 Granularidade

O grão da nova fonte é:

order_id + payment_sequential

Um pedido poderá possuir múltiplos registros de pagamento.

Relação:

ORDER
  |
  | 1
  |
  | N
  v
PAYMENT

`payment_sequential` deverá ser interpretado dentro do contexto do pedido e não como identificador global.

---

## 5.5 Nova medida financeira

Após a inclusão da fonte será possível calcular:

valor_pago_pedido =
SUM(payment_value)
GROUP BY order_id

Passam a existir duas medidas distintas:

valor_calculado_pedido
=
SUM(price + freight_value)

valor_pago_pedido
=
SUM(payment_value)

Os dois valores deverão ser preservados.

A introdução do valor pago não elimina o valor calculado anteriormente.

---

## 5.6 Reconciliação

Deverá ser realizada uma comparação por pedido entre:

SUM(price + freight_value)

e:

SUM(payment_value)

As divergências existentes na origem deverão ser preservadas.

Não será permitido:

- substituir valores;
- corrigir divergências artificialmente;
- descartar pedidos apenas para obter igualdade;
- modificar os dados de origem.

A reconciliação possui finalidade de validação e caracterização da nova fonte.

---

# 6. Impacto da M1 sobre as consultas

## 6.1 Q1 — Valor bruto dos itens vendidos

Q1 não será alterada.

Sua definição permanece:

SUM(order_items.price)

para pedidos entregues.

Q1 funciona como consulta de controle para verificar que a inclusão da nova fonte não altera resultados independentes dela.

---

## 6.2 Q2 — Ticket médio

### Antes da M1

Q2 calcula:

valor_calculado_pedido =
SUM(price + freight_value)
GROUP BY order_id

ticket_medio_calculado =
AVG(valor_calculado_pedido)

### Após a M1

O requisito passa a incluir o ticket médio baseado no pagamento registrado:

valor_pago_pedido =
SUM(payment_value)
GROUP BY order_id

ticket_medio_pago =
AVG(valor_pago_pedido)

Q2 é, portanto, uma consulta existente afetada pela M1.

O objetivo é medir o esforço necessário para adaptar uma consulta previamente implementada à nova fonte financeira.

---

## 6.3 Q3 — Relatório mensal de desempenho por UF

Q3 também será alterada.

Além dos indicadores existentes, serão adicionados:

- valor_pago;
- ticket_medio_pago.

Os indicadores anteriores deverão permanecer:

- valor_calculado_pedidos;
- ticket_medio_calculado.

Isso permitirá que o relatório apresente simultaneamente o valor anteriormente calculado e a nova medida obtida da fonte de pagamentos.

---

# 7. Controle de granularidade da M1

A inclusão de pagamentos cria duas relações 1:N originadas em pedido:

          ORDER
         /     \
        v       v
ORDER_ITEM    PAYMENT
   1:N          1:N

Um join direto entre essas estruturas poderá provocar fan-out.

Exemplo:

2 itens
x
3 pagamentos
=
6 linhas

Esse comportamento poderá duplicar:

- valores dos itens;
- valores de frete;
- valores de pagamento;
- métricas calculadas.

A integração deverá respeitar os respectivos grãos.

Fluxo lógico:

ORDER_ITEMS
    |
    v
agregação por order_id
    |
    v
ITENS_POR_PEDIDO
        \
         \
          v
         ORDER
          ^
         /
        /
PAGAMENTOS_POR_PEDIDO
    ^
    |
agregação por order_id
    ^
    |
ORDER_PAYMENTS

A implementação física poderá variar entre as arquiteturas, mas os resultados deverão ser equivalentes.

---

# 8. Validações da M1

Após a implementação, deverão ser verificadas:

### Integridade

Todos os pagamentos processados deverão continuar associados ao respectivo `order_id`.

### Quantidade de registros

A quantidade processada deverá ser reconciliada com `raw.order_payments`.

### Valor total pago

Comparar:

SUM(raw.order_payments.payment_value)

com o resultado das duas implementações.

### Valor pago por pedido

Comparar:

SUM(payment_value)
GROUP BY order_id

entre:

- raw;
- Kimball;
- Data Vault + Data Mart.

### Reconciliação

Preservar as diferenças existentes entre:

SUM(price + freight_value)

e:

SUM(payment_value)

### Q1

Resultado equivalente ao estado anterior.

### Q2

Kimball e Data Vault + Data Mart deverão produzir o mesmo `ticket_medio_pago`.

### Q3

Todas as dimensões e indicadores deverão ser equivalentes entre as duas abordagens.

---

# 9. M2 — Novos atributos do ciclo logístico do pedido

## 9.1 Objetivo

Avaliar o impacto da disponibilização de novos atributos em uma fonte já integrada ao ambiente.

Diferentemente da M1, não será adicionada uma nova fonte nem uma nova relação.

O objetivo é observar como cada arquitetura evolui quando uma entidade existente passa a disponibilizar novas informações analíticas.

---

## 9.2 Estado anterior

Em T1 já existem informações suficientes para medir:

- data da compra;
- data de entrega ao cliente;
- data estimada de entrega;
- tempo total de entrega;
- percentual de pedidos atrasados.

Entretanto, as etapas intermediárias do ciclo logístico ainda não estão disponíveis analiticamente.

---

## 9.3 Fonte afetada

Fonte existente:

`orders`

Novos atributos disponibilizados em T2:

- order_approved_at;
- order_delivered_carrier_date.

Embora esses campos estejam presentes fisicamente no CSV original, deverão ser tratados como indisponíveis nos estados anteriores do experimento.

M2 representa a evolução do schema lógico disponível ao ambiente analítico.

---

# 10. Novas métricas logísticas

A inclusão dos novos atributos permitirá decompor o tempo total de entrega em etapas.

Fluxo:

COMPRA
  |
  | tempo de aprovação
  v
APROVAÇÃO
  |
  | tempo de preparação
  v
TRANSPORTADORA
  |
  | tempo de transporte
  v
CLIENTE

---

## 10.1 Tempo de aprovação

Definição:

tempo_aprovacao =
order_approved_at
-
order_purchase_timestamp

Na Q3 deverá ser calculado:

tempo_medio_aprovacao

---

## 10.2 Tempo de preparação

Definição:

tempo_preparacao =
order_delivered_carrier_date
-
order_approved_at

Na Q3 deverá ser calculado:

tempo_medio_preparacao

---

## 10.3 Tempo de transporte

Definição:

tempo_transporte =
order_delivered_customer_date
-
order_delivered_carrier_date

Na Q3 deverá ser calculado:

tempo_medio_transporte

---

# 11. Impacto da M2 sobre as consultas

## Q1

Não será alterada.

## Q2

Não será alterada.

## Q3

Será alterada.

Os seguintes indicadores serão adicionados:

- tempo_medio_aprovacao;
- tempo_medio_preparacao;
- tempo_medio_transporte.

Os indicadores logísticos existentes deverão permanecer, incluindo:

- tempo_medio_entrega_dias;
- percentual_entregas_atrasadas.

A M2 deverá ampliar a capacidade analítica do relatório sem remover indicadores existentes.

---

# 12. Tratamento de dados na M2

As datas originais deverão ser preservadas.

Nenhum valor deverá ser corrigido ou preenchido artificialmente.

---

## 12.1 Valores nulos

Quando uma das datas necessárias para determinado indicador estiver ausente, o pedido deverá ser excluído apenas daquele indicador.

Exemplo:

Se `order_approved_at` estiver nulo:

- o pedido não participa de `tempo_medio_aprovacao`;
- métricas que não dependem desse campo continuam utilizando o pedido normalmente.

Um valor nulo não deverá provocar a exclusão completa do pedido das demais análises.

---

## 12.2 Intervalos temporais negativos

Foram identificados registros em que a ordem temporal dos eventos é inconsistente.

Por isso:

- valores negativos não deverão ser substituídos por zero;
- datas não deverão ser alteradas;
- o pedido não deverá ser removido de todos os indicadores;
- o intervalo inválido deverá ser excluído apenas da média que depende dele.

Regras:

tempo_aprovacao >= 0

tempo_preparacao >= 0

tempo_transporte >= 0

Os casos inválidos deverão ser registrados como anomalias de qualidade dos dados.

---

# 13. Validações da M2

Após a implementação deverão ser verificadas:

### Preservação dos indicadores anteriores

Q1 e Q2 deverão manter os resultados do estado anterior.

Os indicadores existentes de Q3 que não dependem dos novos atributos também deverão permanecer equivalentes.

### Novos indicadores

Kimball e Data Vault + Data Mart deverão produzir valores equivalentes para:

- tempo_medio_aprovacao;
- tempo_medio_preparacao;
- tempo_medio_transporte.

### Tratamento de nulos

A quantidade de registros utilizados em cada indicador deverá respeitar a disponibilidade das datas necessárias.

### Anomalias

Casos de intervalos temporais negativos deverão ser tratados de forma equivalente nas duas arquiteturas.

---

# 14. M3 — Preservação histórica da categoria de produto

## 14.1 Objetivo

Avaliar como cada arquitetura evolui quando surge a necessidade de preservar versões históricas de um atributo descritivo já existente.

A mudança deverá permitir responder qual categoria de produto estava vigente no momento de uma venda, mesmo que o produto tenha sido posteriormente reclassificado.

---

## 14.2 Estado anterior

Até T2, cada produto possui apenas uma categoria analítica corrente:

`product_category_name`

Não existe requisito de preservação das versões anteriores desse atributo.

Em T3 surge o seguinte requisito:

Quando um produto for reclassificado, vendas anteriores deverão continuar associadas à categoria que estava vigente naquele momento.

---

# 15. Natureza da alteração histórica

O dataset Olist utilizado é estático e não fornece uma sequência histórica real de alterações de categoria.

Por esse motivo, M3 utilizará uma reclassificação sintética e controlada.

As alterações não representam mudanças comerciais observadas historicamente na Olist.

Sua finalidade é exclusivamente experimental.

Os dados originais deverão permanecer inalterados.

---

# 16. Data efetiva

Todas as alterações da M3 utilizarão a mesma data efetiva:

2018-01-01

Regra:

venda anterior a 2018-01-01
→ categoria original

venda em ou após 2018-01-01
→ nova categoria

---

# 17. Produtos afetados

Serão utilizados 10 produtos.

Os critérios utilizados para seleção foram:

- `product_category_name` não nulo;
- participação em pedidos entregues;
- pelo menos 5 pedidos antes de 2018-01-01;
- pelo menos 5 pedidos a partir de 2018-01-01;
- seleção dos 10 produtos elegíveis com maior quantidade total de pedidos.

Produtos selecionados:

| product_id | categoria original | nova categoria |
|---|---|---|
| 99a4788cb24856965c36a24e339b6058 | cama_mesa_banho | moveis_decoracao |
| aca2eb7d00ea1a7b8ebd4e68314663af | moveis_decoracao | casa_conforto |
| 422879e10f46682990de24d770e7f83d | ferramentas_jardim | casa_construcao |
| d1c427060a0f73f6b889a5c7c61f2ac4 | informatica_acessorios | eletronicos |
| 389d119b48cf3043d311335e499d9c6b | ferramentas_jardim | casa_construcao |
| 53b36df67ebb7c41585e8d54d6772e08 | relogios_presentes | fashion_bolsas_e_acessorios |
| 368c6c730842d78016ad823897a372db | ferramentas_jardim | casa_construcao |
| 53759a2ecddad2bb87a079a1f1519f73 | ferramentas_jardim | casa_construcao |
| 154e7e31ebfa092203795c972e5804a6 | beleza_saude | perfumaria |
| 2b4609f8948be18874494203496bc318 | beleza_saude | perfumaria |

---

# 18. Arquivo de controle da M3

As alterações são definidas no arquivo:

`data/changes/m3_product_reclassification.csv`

Estrutura:

product_id,
original_category,
new_category,
effective_from

Esse arquivo representa o conjunto controlado de alterações que deverá ser aplicado de forma equivalente às duas arquiteturas.

O CSV original de produtos não deverá ser modificado.

---

# 19. Regra histórica da M3

Para cada produto selecionado existirão duas situações temporais.

Antes da data efetiva:

product_id = P
categoria vigente = categoria original

A partir da data efetiva:

product_id = P
categoria vigente = nova categoria

A identidade do produto permanece a mesma.

Somente o atributo descritivo `product_category_name` sofre alteração temporal.

---

# 20. Impacto da M3 sobre as consultas existentes

M3 não deverá alterar os requisitos de:

- Q1;
- Q2;
- Q3.

Essas consultas continuarão existindo conforme o estado T2.

A validação específica da preservação histórica utilizará uma consulta própria.

Isso evita modificar artificialmente consultas existentes apenas para demonstrar o comportamento histórico.

---

# 21. Consulta histórica da M3

Será criada uma consulta específica para validar a preservação histórica.

A saída deverá conter:

- mes;
- product_id;
- categoria_vigente;
- categoria_atual;
- quantidade_pedidos;
- quantidade_itens;
- valor_bruto_vendido.

O objetivo é permitir observar simultaneamente:

1. a categoria válida quando a venda ocorreu;
2. a categoria atualmente vigente do produto.

---

## 21.1 Comportamento esperado

Para vendas anteriores a 2018-01-01:

categoria_vigente = categoria_original

categoria_atual = nova_categoria

Para vendas realizadas em ou após 2018-01-01:

categoria_vigente = nova_categoria

categoria_atual = nova_categoria

---

# 22. Invariantes da M3

A reclassificação de categoria não poderá alterar os fatos de venda.

Para os 10 produtos envolvidos, os seguintes valores deverão permanecer constantes:

quantidade de pedidos:
3213

quantidade de itens:
3814

valor bruto:
280037.69

Esses valores funcionam como invariantes da mudança.

M3 poderá modificar apenas a classificação temporal dos dados.

Não poderá modificar:

- quantidade de pedidos;
- quantidade de itens;
- preço dos itens;
- valor bruto total.

---

# 23. Validações da M3

Após a implementação deverão ser verificadas:

### Categoria atual

Todos os 10 produtos deverão apresentar a nova categoria como categoria corrente após a aplicação da mudança.

### Histórico anterior

Vendas anteriores a 2018-01-01 deverão continuar associadas à categoria original.

### Histórico posterior

Vendas em ou após 2018-01-01 deverão estar associadas à nova categoria.

### Identidade

O `product_id` deverá permanecer inalterado.

### Quantidade de pedidos

Deverá permanecer:

3213

### Quantidade de itens

Deverá permanecer:

3814

### Valor bruto

Deverá permanecer:

280037.69

### Equivalência

Kimball e Data Vault + Data Mart deverão produzir resultados equivalentes para a consulta histórica.

---

# 24. Aspectos comparados em cada mudança

Para M1, M2 e M3 deverão ser registradas as alterações provocadas em cada arquitetura.

A análise será feita sempre considerando o delta entre o estado anterior e posterior.

---

## 24.1 Estrutura

Registrar:

- tabelas criadas;
- tabelas alteradas;
- views criadas;
- views alteradas;
- outros objetos estruturais necessários.

A quantidade de tabelas, isoladamente, não deverá ser utilizada como medida de superioridade.

---

## 24.2 Rotinas de carga

Registrar:

- rotinas criadas;
- rotinas alteradas;
- dependências novas;
- dependências existentes modificadas.

---

## 24.3 Reprocessamento

Classificar a mudança como:

- sem reprocessamento;
- reprocessamento parcial;
- reprocessamento completo.

A classificação deverá ser acompanhada de justificativa.

---

## 24.4 Consumo analítico

Registrar:

- consultas existentes afetadas;
- consultas existentes preservadas;
- novas consultas;
- novos indicadores;
- indicadores modificados.

Resumo esperado:

| Consulta | M1 | M2 | M3 |
|---|---|---|---|
| Q1 | não alterada | não alterada | não alterada |
| Q2 | alterada | não alterada | não alterada |
| Q3 | alterada | alterada | não alterada |
| Consulta histórica M3 | inexistente | inexistente | criada |

---

## 24.5 Granularidade e relacionamentos

Registrar quando a mudança provocar:

- novo grão;
- nova cardinalidade;
- novos joins;
- necessidade de pré-agregação;
- risco de fan-out;
- alteração de relacionamentos existentes.

Esse aspecto será especialmente relevante para M1.

---

## 24.6 Preservação histórica

Registrar:

- necessidade de versionamento;
- quantidade de estruturas alteradas para suportar histórico;
- necessidade de reprocessar dados anteriores;
- capacidade de consultar valor atual;
- capacidade de consultar valor vigente em determinado momento.

Esse aspecto será especialmente relevante para M3.

---

## 24.7 Rastreabilidade

Avaliar a capacidade de identificar:

- origem dos dados;
- momento da carga;
- origem de uma alteração;
- relacionamento entre registros;
- versão utilizada em determinada análise.

---

## 24.8 Equivalência funcional

Antes da análise de esforço ou complexidade, os resultados das duas arquiteturas deverão ser validados.

Uma implementação que produza resultados incorretos não poderá ser comparada como solução funcionalmente equivalente.

---

# 25. Separação das camadas

A comparação deverá considerar que as duas abordagens possuem estruturas arquiteturais diferentes.

Kimball:

RAW
 |
 v
MODELO DIMENSIONAL
 |
 v
CONSULTAS

Data Vault:

RAW
 |
 v
DATA VAULT
 |
 v
DATA MART DIMENSIONAL
 |
 v
CONSULTAS

Por esse motivo, a análise deverá distinguir quando possível:

- impacto na camada de armazenamento ou integração;
- impacto na camada de consumo analítico.

O número total de objetos não deverá ser interpretado isoladamente.

---

# 26. Resumo dos cenários

## T0 — Baseline

Fontes:

- customers;
- orders;
- order_items;
- products;
- sellers.

Consultas:

- Q1;
- Q2;
- Q3.

---

## M1 — Nova fonte

Nova fonte:

- order_payments.

Principal característica:

- nova granularidade;
- relação ORDER 1:N PAYMENT;
- risco de fan-out;
- alteração de consultas existentes.

Impacto:

Q1:
não alterada.

Q2:
alterada.

Q3:
alterada.

---

## M2 — Novos atributos

Fonte existente:

- orders.

Novos atributos:

- order_approved_at;
- order_delivered_carrier_date.

Principal característica:

- evolução do schema de fonte existente;
- nenhuma nova relação;
- ampliação do detalhamento logístico.

Impacto:

Q1:
não alterada.

Q2:
não alterada.

Q3:
alterada.

Novos indicadores:

- tempo_medio_aprovacao;
- tempo_medio_preparacao;
- tempo_medio_transporte.

---

## M3 — Histórico

Entidade:

- product.

Atributo:

- product_category_name.

Data efetiva:

2018-01-01.

Produtos:

10.

Principal característica:

- preservação de versões históricas de atributo descritivo.

Impacto:

Q1:
não alterada.

Q2:
não alterada.

Q3:
não alterada.

Nova consulta:

- consulta histórica de reclassificação.

Invariantes:

- 3213 pedidos;
- 3814 itens;
- valor bruto de 280037.69.

---

# 27. Escopo final das mudanças

O experimento utilizará três mudanças principais.

Não será introduzida uma quarta mudança apenas para aumentar a quantidade de cenários.

As três mudanças escolhidas representam classes distintas de evolução:

M1:
nova fonte e nova cardinalidade.

M2:
novos atributos em estrutura existente.

M3:
novo requisito de preservação histórica.

Esse conjunto será utilizado para avaliar a evolução progressiva das duas arquiteturas ao longo dos estados T0, T1, T2 e T3.