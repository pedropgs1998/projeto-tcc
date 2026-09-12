# Baseline Experimental

## 1. Objetivo

Este documento define o estado inicial do experimento utilizado na comparação entre:

- Modelagem Dimensional de Kimball;
- Data Vault 2.0 com Data Mart dimensional para consumo analítico.

O baseline representa o estado T0 do ambiente analítico, antes da introdução das mudanças controladas previstas no experimento.

As mesmas fontes, regras de negócio, filtros e consultas analíticas deverão ser implementadas nas duas abordagens.

O objetivo é garantir que os resultados posteriores sejam comparáveis e que mudanças no modelo não sejam realizadas de forma retroativa em função dos resultados observados durante o experimento.

---

## 2. Dataset

Dataset utilizado:

Brazilian E-Commerce Public Dataset by Olist

Os arquivos CSV originais são mantidos na pasta:

data/raw/

A camada raw do PostgreSQL representa a ingestão dos arquivos originais e não pertence a nenhuma das duas arquiteturas comparadas.

Ela é comum aos dois experimentos e funciona como origem controlada dos dados.

Estrutura geral:

Olist CSV
    |
    v
raw
    |
    +------------------> Kimball
    |
    +------------------> Data Vault 2.0
                              |
                              v
                          Data Mart

---

## 3. Fontes utilizadas no baseline

O baseline utiliza somente as seguintes fontes:

- olist_customers_dataset.csv
- olist_orders_dataset.csv
- olist_order_items_dataset.csv
- olist_products_dataset.csv
- olist_sellers_dataset.csv

Correspondentes às tabelas:

- raw.customers
- raw.orders
- raw.order_items
- raw.products
- raw.sellers

---

## 4. Fontes excluídas do baseline

As seguintes fontes estão disponíveis fisicamente na camada raw, mas não poderão ser utilizadas na modelagem, carga ou consultas analíticas do baseline:

- raw.order_payments
- raw.order_reviews
- raw.geolocation
- raw.product_category_translation

A existência dessas tabelas em raw não significa que façam parte do ambiente analítico em T0.

### 4.1 order_payments

Será introduzida posteriormente como uma mudança controlada de nova fonte.

Portanto, no baseline não poderão ser utilizados:

- payment_sequential
- payment_type
- payment_installments
- payment_value

### 4.2 order_reviews

Não participa das consultas analíticas do baseline.

### 4.3 geolocation

Não será utilizada, pois as informações de estado e cidade disponíveis em customers e sellers são suficientes para o escopo definido.

### 4.4 product_category_translation

Não será utilizada. As categorias originais do dataset serão mantidas.

---

## 5. Entidades e identificadores

### 5.1 Pedido

Identificador:

order_id

O profiling confirmou que order_id é único na fonte orders.

Grão:

1 registro = 1 pedido

---

### 5.2 Item do pedido

Identificador:

order_id + order_item_id

order_item_id não é globalmente único.

Seu significado é sequencial dentro de determinado pedido.

Portanto, order_item_id não poderá ser tratado isoladamente como chave única do item.

Grão:

1 registro = 1 item dentro de um pedido

---

### 5.3 Cliente

A fonte possui dois identificadores relevantes:

- customer_id
- customer_unique_id

customer_id representa o identificador utilizado para relacionar o cliente ao pedido na fonte.

Relacionamento:

orders.customer_id
    |
    v
customers.customer_id

customer_unique_id representa a identidade de negócio do cliente utilizada no experimento.

Será considerado o identificador lógico do cliente nas duas arquiteturas.

Um mesmo customer_unique_id pode possuir múltiplos customer_id.

Portanto:

Business Key do cliente = customer_unique_id

customer_id permanece necessário para preservar o relacionamento existente na fonte entre pedido e cliente.

---

### 5.4 Produto

Identificador:

product_id

Grão:

1 registro = 1 produto

No baseline, entre os atributos descritivos de produto utilizados analiticamente, será considerado principalmente:

product_category_name

Os atributos físicos do produto serão reservados para uma mudança posterior do experimento.

---

### 5.5 Vendedor

Identificador:

seller_id

Grão:

1 registro = 1 vendedor

A relação entre produtos e vendedores não é 1:1.

Um vendedor pode comercializar múltiplos produtos e um mesmo produto pode aparecer associado a múltiplos vendedores.

Por esse motivo, seller fará parte do baseline mesmo não sendo necessário para todas as consultas analíticas.

---

## 6. Processos analíticos

O baseline possui dois grãos analíticos principais.

### 6.1 Processo de pedido e entrega

Grão:

1 linha por order_id

Esse grão é utilizado principalmente para:

- quantidade de pedidos;
- quantidade de clientes;
- ticket médio;
- tempo de entrega;
- análise de atraso.

### 6.2 Processo de venda de itens

Grão:

1 linha por order_id + order_item_id

Esse grão é utilizado principalmente para:

- quantidade de itens;
- quantidade de produtos;
- quantidade de vendedores;
- valor dos itens;
- valor do frete;
- análises relacionadas ao produto.

---

## 7. População analítica

O baseline utilizará como população principal:

order_status = 'delivered'

Pedidos cancelados, indisponíveis, em processamento ou ainda não entregues não deverão participar dos indicadores principais de vendas e entrega.

Isso evita misturar pedidos incompletos com transações efetivamente concluídas.

### 7.1 Regras adicionais para métricas logísticas

Para cálculos que dependem de datas de entrega, deverão ser considerados somente registros com os campos necessários preenchidos.

Para tempo real de entrega:

order_purchase_timestamp IS NOT NULL
AND order_delivered_customer_date IS NOT NULL

Para análise de atraso:

order_delivered_customer_date IS NOT NULL
AND order_estimated_delivery_date IS NOT NULL

---

## 8. Consultas analíticas do baseline

O experimento utilizará três consultas analíticas de complexidade crescente.

Elas serão denominadas:

- Q1
- Q2
- Q3

Essas consultas deverão existir tanto na implementação Kimball quanto na implementação Data Vault 2.0 + Data Mart.

Os resultados deverão ser funcionalmente equivalentes entre as duas arquiteturas.

---

## 9. Q1 — Valor bruto dos itens vendidos

### Complexidade

Simples.

### Objetivo

Validar a equivalência funcional básica entre as duas implementações.

### Pergunta de negócio

Qual o valor bruto dos itens vendidos em pedidos entregues?

### Fontes necessárias

- orders
- order_items

### Regra

SUM(order_items.price)

considerando somente itens pertencentes a pedidos com:

order_status = 'delivered'

### Grãos envolvidos

Origem:

item do pedido

Resultado:

agregação global ou por período, conforme execução da consulta.

### Observação

Esse indicador não representa:

- receita;
- faturamento;
- valor efetivamente pago.

A fonte de pagamentos ainda não existe no ambiente analítico em T0.

Sua denominação oficial será:

Valor bruto dos itens vendidos

### Papel experimental

Q1 funcionará como consulta de controle.

Mudanças futuras não necessariamente deverão afetá-la.

Isso permitirá verificar se uma evolução estrutural pode ocorrer sem alterar consultas analíticas independentes da nova informação.

---

## 10. Q2 — Ticket médio calculado dos pedidos

### Complexidade

Intermediária.

### Objetivo

Avaliar uma consulta que exige alteração de granularidade antes da agregação final.

### Pergunta de negócio

Qual o valor médio calculado dos pedidos entregues?

### Fontes necessárias

- orders
- order_items

### Regra

Primeiramente deve ser calculado o valor de cada pedido:

valor_calculado_pedido =
SUM(price + freight_value)
GROUP BY order_id

Posteriormente:

ticket_medio_calculado =
AVG(valor_calculado_pedido)

### Fluxo lógico

ORDER_ITEM
    |
    v
agregação por order_id
    |
    v
valor calculado do pedido
    |
    v
AVG
    |
    v
ticket médio calculado

### Regra importante

Não utilizar:

AVG(order_items.price)

porque isso representa preço médio dos itens e não ticket médio do pedido.

### Papel experimental

Q2 será uma das consultas existentes que deverá sofrer evolução quando a fonte de pagamentos for introduzida.

No baseline:

ticket médio =
itens + frete

Após a introdução de pagamentos, o requisito poderá utilizar payment_value para representar o valor efetivamente pago.

Dessa forma será possível medir o impacto de uma nova fonte sobre uma consulta analítica já existente.

---

## 11. Q3 — Relatório mensal de desempenho por UF

### Complexidade

Complexa.

### Objetivo

Representar um cenário de consumo analítico mais próximo de um relatório real, combinando diferentes entidades, granularidades e indicadores.

### Pergunta de negócio

Como evolui mensalmente o desempenho comercial e logístico dos pedidos entregues em cada estado dos clientes?

### Dimensões do resultado

- mês;
- UF do cliente.

O mês será derivado de:

order_purchase_timestamp

A UF será obtida de:

customers.customer_state

---

## 11.1 Colunas do relatório

A saída de Q3 deverá conter:

- mes
- customer_state
- quantidade_pedidos
- quantidade_clientes
- quantidade_itens
- quantidade_produtos
- quantidade_vendedores
- valor_bruto_itens
- valor_frete
- valor_calculado_pedidos
- ticket_medio_calculado
- tempo_medio_entrega_dias
- percentual_entregas_atrasadas

---

## 11.2 Fontes utilizadas

- customers
- orders
- order_items
- products
- sellers

---

## 11.3 Estrutura conceitual

CUSTOMER
    |
    v
ORDER
    |
    v
ORDER_ITEM
   /   \
  v     v
PRODUCT SELLER

---

## 11.4 Regras dos indicadores

### quantidade_pedidos

COUNT(DISTINCT order_id)

### quantidade_clientes

COUNT(DISTINCT customer_unique_id)

### quantidade_itens

Número total de registros de order_items pertencentes aos pedidos analisados.

### quantidade_produtos

COUNT(DISTINCT product_id)

no contexto de mês e UF.

### quantidade_vendedores

COUNT(DISTINCT seller_id)

no contexto de mês e UF.

### valor_bruto_itens

SUM(price)

### valor_frete

SUM(freight_value)

### valor_calculado_pedidos

Primeiramente:

SUM(price + freight_value)

por pedido.

Posteriormente, os valores dos pedidos são agregados no contexto:

mês + UF

### ticket_medio_calculado

AVG(valor_calculado_pedido)

no contexto:

mês + UF

### tempo_medio_entrega_dias

Para cada pedido:

order_delivered_customer_date
-
order_purchase_timestamp

Posteriormente:

AVG(tempo_entrega)

considerando apenas pedidos com as datas necessárias preenchidas.

### percentual_entregas_atrasadas

Um pedido é considerado atrasado quando:

order_delivered_customer_date
>
order_estimated_delivery_date

O percentual será:

pedidos entregues com atraso
----------------------------------- * 100
pedidos entregues avaliáveis

---

## 12. Controle de granularidade em Q3

Q3 combina informações em diferentes níveis de granularidade.

Pedido:

order_id

Item:

order_id + order_item_id

Um pedido pode possuir:

- múltiplos itens;
- múltiplos produtos;
- múltiplos vendedores.

Por isso, as métricas relacionadas ao pedido não poderão ser calculadas diretamente após a expansão para o grão de item.

Por exemplo:

- tempo de entrega;
- atraso;
- ticket médio;
- quantidade de pedidos.

Essas métricas devem respeitar o grão de pedido.

Caso contrário, um pedido com vários itens teria peso maior do que um pedido com um único item.

A implementação poderá utilizar:

- CTEs;
- subconsultas;
- tabelas intermediárias;
- views;
- estruturas equivalentes no modelo dimensional.

A estratégia específica será definida durante a implementação, mas o resultado deverá respeitar os grãos definidos neste documento.

---

## 13. Risco de fan-out

O baseline já possui relações 1:N, principalmente:

ORDER
    |
    v
ORDER_ITEM

Mudanças futuras poderão introduzir outras relações 1:N.

A combinação direta dessas relações poderá provocar multiplicação de registros.

Por exemplo, quando pagamentos forem introduzidos:

ORDER
 /   \
v     v
ITEM PAYMENT
1:N   1:N

Um pedido com:

2 itens
3 pagamentos

poderia produzir:

2 x 3 = 6 registros

em um join incorreto.

Esse comportamento não poderá ser corrigido por DISTINCT de maneira arbitrária.

Cada processo deverá ser agregado em seu próprio grão antes da integração quando necessário.

Esse risco será utilizado como parte da avaliação da evolução arquitetural.

---

## 14. Relação entre as consultas

As três consultas representam diferentes níveis de complexidade.

Q1:
consulta simples voltada à equivalência funcional básica.

Q2:
consulta intermediária com mudança de grão e agregação em duas etapas.

Q3:
consulta complexa envolvendo múltiplas entidades, múltiplos grãos, dependências e risco de fan-out.

A progressão permite observar se o impacto das mudanças varia conforme a complexidade do consumo analítico.

---

## 15. Evolução prevista das consultas

As consultas deste documento representam o estado T0.

Mudanças futuras poderão:

- não afetar determinada consulta;
- alterar uma consulta existente;
- adicionar novos indicadores;
- criar novas consultas.

Entretanto, as definições de T0 não deverão ser modificadas retroativamente.

---

## 15.1 Comportamento esperado da introdução de pagamentos

A introdução de order_payments deverá, no mínimo, afetar:

- Q2;
- Q3.

Q1 deverá permanecer funcionalmente independente da nova fonte.

### Q2

Antes:

ticket médio calculado =
AVG(
    SUM(price + freight_value)
    por pedido
)

Após pagamentos:

ticket médio pago =
AVG(
    SUM(payment_value)
    por pedido
)

### Q3

O relatório deverá passar a incorporar informações financeiras provenientes de pagamentos.

Entre elas:

- valor_pago;
- ticket_medio_pago.

O valor calculado a partir de itens e frete poderá ser mantido para comparação com o valor efetivamente pago.

A definição completa de T1 será registrada no documento específico das mudanças experimentais.

---

## 16. Validação funcional

Cada consulta deverá ser executada nas duas implementações:

- Kimball;
- Data Vault 2.0 + Data Mart.

Os resultados deverão ser comparados.

A validação deverá considerar, quando aplicável:

- quantidade de linhas;
- dimensões retornadas;
- somatórios;
- médias;
- percentuais;
- valores por período;
- valores por UF;
- tratamento de NULL;
- tolerância numérica para valores monetários.

Nenhuma diferença de resultado poderá ser atribuída à arquitetura sem antes verificar diferenças de regra ou implementação.

---

## 17. Regras de comparabilidade

Para garantir a validade do experimento:

1. As duas arquiteturas receberão exatamente os mesmos dados de origem.

2. As duas arquiteturas utilizarão as mesmas regras de negócio.

3. Os filtros das consultas deverão ser equivalentes.

4. A camada raw é comum e não faz parte da contagem comparativa de alterações arquiteturais.

5. Uma fonte excluída do baseline não poderá ser utilizada antecipadamente por nenhuma das arquiteturas.

6. Nenhuma arquitetura deverá ser previamente modificada para acomodar requisitos que ainda não existem em T0.

7. Não será permitido alterar retrospectivamente o baseline para reduzir ou aumentar o impacto observado em alguma arquitetura.

8. Mudanças necessárias durante o experimento deverão ser registradas explicitamente.

---

## 18. Fora do escopo

Não fazem parte do baseline ou do objetivo principal do experimento:

- RFM;
- segmentação de clientes;
- churn;
- retenção;
- forecasting;
- machine learning;
- NLP de reviews;
- análise de sentimento;
- dashboards;
- marketing funnel;
- closed deals;
- análise extensa de geolocalização;
- criação de dezenas de KPIs;
- comparação de ferramentas de BI.

O dataset é utilizado como laboratório para a comparação arquitetural, e não como objeto principal de análise de negócio.

---

## 19. Estado T0 congelado

Após a aprovação deste documento, o seguinte estado deverá ser considerado congelado.

### Fontes

- customers
- orders
- order_items
- products
- sellers

### População

order_status = 'delivered'

### Grãos

Pedido:

order_id

Item:

order_id + order_item_id

### Identidade de cliente

customer_unique_id

### Consultas analíticas

Q1 — Valor bruto dos itens vendidos

Q2 — Ticket médio calculado dos pedidos

Q3 — Relatório mensal de desempenho por UF

### Fontes futuras não disponíveis em T0

- order_payments
- order_reviews
- geolocation
- product_category_translation

Qualquer alteração posterior a essas definições deverá ser tratada como mudança explícita do experimento e não como correção silenciosa do baseline.