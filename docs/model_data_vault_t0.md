# Modelo Data Vault 2.0 — Estado T0

## 1. Objetivo

Este documento especifica o modelo lógico Data Vault 2.0 utilizado no estado inicial T0 do experimento.

O modelo é construído a partir das mesmas fontes e regras de negócio utilizadas no modelo dimensional Kimball, porém respeitando os princípios de modelagem do Data Vault 2.0.

A arquitetura considerada para esta abordagem é:

```text
raw
 ↓
Data Vault
 ↓
Data Mart dimensional
 ↓
Consultas analíticas
```

O Raw Vault é responsável por preservar as chaves de negócio, os relacionamentos e os atributos provenientes das fontes.

O Data Mart é responsável por transformar essas estruturas em um modelo adequado ao consumo analítico.

As consultas Q1, Q2 e Q3 serão executadas sobre o Data Mart, e não diretamente sobre o Raw Vault.

O resultado analítico produzido deverá ser funcionalmente equivalente ao obtido pela implementação Kimball.

---

## 2. Escopo do estado T0

As fontes utilizadas no T0 são:

- `raw.customers`
- `raw.orders`
- `raw.order_items`
- `raw.products`
- `raw.sellers`

As seguintes fontes existentes na camada `raw` não fazem parte do baseline T0:

- `raw.order_payments`
- `raw.order_reviews`
- `raw.geolocation`
- `raw.product_category_name_translation`

No estado T0 também não fazem parte do modelo:

- `order_approved_at`;
- `order_delivered_carrier_date`;
- histórico efetivo de reclassificação de categorias de produto;
- informações de pagamento.

Esses elementos pertencem às mudanças posteriores do experimento.

---

## 3. Princípios de modelagem

A modelagem utiliza três tipos principais de estruturas:

- Hub;
- Link;
- Satellite.

### 3.1 Hub

Representa uma entidade de negócio identificada por uma Business Key estável.

No T0, os conceitos representados por Hubs são:

```text
Pedido
Cliente
Produto
Vendedor
```

Os Hubs armazenam principalmente:

```text
Hash Key
Business Key
load_timestamp
record_source
```

Os atributos descritivos não são armazenados no Hub.

### 3.2 Link

Representa um relacionamento entre duas ou mais entidades de negócio.

No modelo T0 existem relacionamentos correspondentes a:

```text
Pedido ↔ Cliente

Pedido ↔ Produto ↔ Vendedor
```

Os Links armazenam as Hash Keys das entidades participantes e os metadados técnicos de carga.

### 3.3 Satellite

Representa atributos descritivos ou contextuais associados a um Hub ou Link.

Uma estrutura geral de Satellite é:

```text
parent_hash_key
atributos descritivos
hashdiff
load_timestamp
record_source
```

Os Satellites permitem armazenar diferentes versões dos atributos ao longo das cargas.

No estado T0 existe somente o estado inicial dos dados carregados.

A existência de Satellites não significa que as mudanças futuras do experimento já estejam implementadas.

---

## 4. Visão geral do modelo T0

O Raw Vault T0 possui:

```text
4 Hubs
2 Links
5 Satellites
```

Total:

```text
11 estruturas principais
```

As estruturas são:

```text
HUBS
-----

hub_order
hub_customer
hub_product
hub_seller


LINKS
-----

link_order_customer
link_order_item


SATELLITES
----------

sat_order
sat_order_customer
sat_product
sat_seller
sat_order_item
```

Representação simplificada:

```text
                         ┌─────────────┐
                         │  SAT_ORDER  │
                         └──────┬──────┘
                                │
                         ┌──────▼──────┐
                         │  HUB_ORDER  │
                         └───┬─────┬───┘
                             │     │
             ┌───────────────┘     └──────────────────┐
             │                                        │
   ┌─────────▼────────────┐               ┌───────────▼──────────┐
   │ LINK_ORDER_CUSTOMER  │               │   LINK_ORDER_ITEM    │
   └─────────┬────────────┘               └─────┬─────────┬──────┘
             │                                   │         │
             │                                   │         │
      ┌──────▼───────┐                 ┌────────▼───┐ ┌───▼────────┐
      │ HUB_CUSTOMER │                 │ HUB_PRODUCT│ │ HUB_SELLER │
      └──────────────┘                 └──────┬─────┘ └─────┬──────┘
                                             │             │
                                      ┌──────▼─────┐ ┌────▼──────┐
                                      │SAT_PRODUCT │ │SAT_SELLER │
                                      └────────────┘ └───────────┘


   LINK_ORDER_CUSTOMER
            │
            ▼
   SAT_ORDER_CUSTOMER


      LINK_ORDER_ITEM
            │
            ▼
      SAT_ORDER_ITEM
```

---

## 5. Hubs

### 5.1 hub_order

#### Conceito

Representa um pedido.

#### Business Key

```text
order_id
```

#### Grão

Uma linha por `order_id`.

#### Estrutura lógica

```text
hub_order
---------

order_hk
order_id
load_timestamp
record_source
```

#### Origem

```text
raw.orders
```

#### Observações

`order_hk` é uma Hash Key determinística calculada a partir de `order_id`.

Os atributos descritivos do pedido não ficam no Hub. Eles são armazenados em `sat_order`.

---

### 5.2 hub_customer

#### Conceito

Representa a identidade lógica de um cliente.

#### Business Key

```text
customer_unique_id
```

#### Grão

Uma linha por `customer_unique_id`.

#### Estrutura lógica

```text
hub_customer
------------

customer_hk
customer_unique_id
load_timestamp
record_source
```

#### Origem

```text
raw.customers
```

#### Justificativa

No dataset Olist existem:

```text
99.441 customer_id distintos
96.096 customer_unique_id distintos
```

Um mesmo `customer_unique_id` pode estar associado a diferentes `customer_id`.

Dessa forma:

```text
customer_unique_id
```

representa a identidade lógica do cliente, enquanto:

```text
customer_id
```

representa uma ocorrência desse cliente na fonte.

Por esse motivo, `customer_unique_id` é utilizado como Business Key do Hub.

Essa decisão é diferente do modelo dimensional Kimball, no qual `dim_customer` possui grão `customer_id`.

A diferença é intencional e decorre das diferentes finalidades das duas arquiteturas.

No Kimball, o objetivo é facilitar o consumo analítico e preservar diretamente o contexto associado ao `customer_id`.

No Raw Vault, o objetivo é preservar a identidade lógica do cliente e os diferentes contextos associados a essa identidade.

---

### 5.3 hub_product

#### Conceito

Representa um produto.

#### Business Key

```text
product_id
```

#### Grão

Uma linha por `product_id`.

#### Estrutura lógica

```text
hub_product
-----------

product_hk
product_id
load_timestamp
record_source
```

#### Origem

```text
raw.products
```

---

### 5.4 hub_seller

#### Conceito

Representa um vendedor.

#### Business Key

```text
seller_id
```

#### Grão

Uma linha por `seller_id`.

#### Estrutura lógica

```text
hub_seller
----------

seller_hk
seller_id
load_timestamp
record_source
```

#### Origem

```text
raw.sellers
```

---

## 6. Links

### 6.1 link_order_customer

#### Conceito

Representa a associação entre um pedido e a identidade lógica do cliente responsável pelo pedido.

#### Grão

Uma linha por relacionamento:

```text
order_id
+
customer_unique_id
```

No dataset utilizado, cada pedido possui um único cliente.

#### Estrutura lógica

```text
link_order_customer
-------------------

order_customer_hk

order_hk
customer_hk

load_timestamp
record_source
```

#### Origem

O relacionamento é obtido a partir de:

```text
raw.orders
+
raw.customers
```

utilizando:

```text
orders.customer_id = customers.customer_id
```

#### Hash Key do Link

A Hash Key do relacionamento será calculada de maneira determinística a partir das Business Keys participantes:

```text
order_id
+
customer_unique_id
```

---

### 6.2 link_order_item

#### Conceito

Representa uma ocorrência de item de pedido, relacionando:

```text
Pedido
Produto
Vendedor
```

#### Grão

Uma linha por:

```text
(order_id, order_item_id)
```

#### Estrutura lógica

```text
link_order_item
---------------

order_item_hk

order_hk
product_hk
seller_hk

order_item_id

load_timestamp
record_source
```

#### Origem

```text
raw.order_items
```

com resolução das respectivas Business Keys de:

```text
raw.orders
raw.products
raw.sellers
```

#### Dependent Child

`order_item_id` não representa uma entidade de negócio independente.

O mesmo valor ocorre em diferentes pedidos:

```text
pedido A → item 1
pedido B → item 1
pedido C → item 1
```

Portanto, não é criado:

```text
hub_order_item
```

O atributo `order_item_id` é utilizado como Dependent Child do relacionamento.

Ele diferencia múltiplas ocorrências dentro de um mesmo pedido.

A identidade lógica da ocorrência do Link considera:

```text
order_id
product_id
seller_id
order_item_id
```

Essa composição impede que dois itens diferentes do mesmo pedido envolvendo o mesmo produto e vendedor sejam indevidamente consolidados em um único relacionamento.

Embora produto e vendedor participem da composição lógica do Link, o grão analítico preservado continua sendo:

```text
(order_id, order_item_id)
```

pois essa combinação foi validada como única na fonte.

---

## 7. Satellites

### 7.1 sat_order

#### Parent

```text
hub_order
```

#### Grão lógico

Uma versão dos atributos de um pedido para cada alteração identificada nas cargas.

#### Estrutura lógica

```text
sat_order
---------

order_hk

order_status
order_purchase_timestamp
order_delivered_customer_date
order_estimated_delivery_date

hashdiff
load_timestamp
record_source
```

#### Origem

```text
raw.orders
```

#### Atributos deliberadamente ausentes em T0

Não são carregados:

```text
order_approved_at
order_delivered_carrier_date
```

Esses atributos pertencem à mudança M2.

#### Observação

No T0 é carregado apenas o estado inicialmente disponível no dataset.

A estrutura do Satellite permite historização das cargas, porém nenhuma regra específica das mudanças posteriores é antecipada.

---

### 7.2 sat_order_customer

#### Parent

```text
link_order_customer
```

#### Objetivo

Preservar a ocorrência de cliente utilizada pela fonte no contexto daquele pedido.

#### Estrutura lógica

```text
sat_order_customer
------------------

order_customer_hk

customer_id
customer_zip_code_prefix
customer_city
customer_state

hashdiff
load_timestamp
record_source
```

#### Origem

```text
raw.customers
```

associada ao pedido por:

```text
raw.orders.customer_id
```

#### Justificativa

O Hub representa:

```text
customer_unique_id
```

ou seja, a identidade lógica do cliente.

Entretanto, atributos como:

```text
customer_zip_code_prefix
customer_city
customer_state
```

estão associados na fonte a um determinado:

```text
customer_id
```

Um mesmo cliente lógico pode possuir diferentes `customer_id` em diferentes ocorrências.

Armazenar diretamente a localização em um Satellite do `hub_customer` poderia fazer diferentes ocorrências da mesma pessoa serem interpretadas como simples alterações de um único estado do cliente, perdendo o contexto específico utilizado pelo pedido.

Por isso, no T0 esses atributos são preservados no contexto do relacionamento Pedido–Cliente.

Isso mantém simultaneamente:

```text
identidade lógica:
customer_unique_id

ocorrência da fonte:
customer_id

contexto da ocorrência:
CEP, cidade e UF
```

Essa estrutura também permite reconstruir posteriormente a dimensão de cliente no grão `customer_id` necessária ao Data Mart.

---

### 7.3 sat_product

#### Parent

```text
hub_product
```

#### Estrutura lógica

```text
sat_product
-----------

product_hk

product_category_name

hashdiff
load_timestamp
record_source
```

#### Origem

```text
raw.products
```

#### Observação sobre histórico

No T0, `product_category_name` representa somente o estado inicialmente carregado.

Não existe ainda:

```text
effective_from
effective_to
categoria_vigente
categoria_atual
reclassificação histórica
```

Esses conceitos pertencem à mudança M3.

A capacidade técnica de armazenar múltiplas versões em um Satellite não deve ser confundida com a implementação da regra de negócio de temporalidade efetiva definida posteriormente em M3.

---

### 7.4 sat_seller

#### Parent

```text
hub_seller
```

#### Estrutura lógica

```text
sat_seller
----------

seller_hk

seller_zip_code_prefix
seller_city
seller_state

hashdiff
load_timestamp
record_source
```

#### Origem

```text
raw.sellers
```

---

### 7.5 sat_order_item

#### Parent

```text
link_order_item
```

#### Estrutura lógica

```text
sat_order_item
--------------

order_item_hk

price
freight_value

hashdiff
load_timestamp
record_source
```

#### Origem

```text
raw.order_items
```

#### Justificativa

`price` e `freight_value` não representam entidades ou chaves de negócio.

Eles descrevem a ocorrência específica do item do pedido.

Por isso pertencem ao Satellite associado a `link_order_item`.

---

## 8. Hash Keys

O modelo utilizará Hash Keys determinísticas em Hubs e Links.

O algoritmo adotado será:

```text
SHA-256
```

No PostgreSQL será utilizada a extensão:

```sql
pgcrypto
```

A representação física prevista para as Hash Keys é hexadecimal:

```text
CHAR(64)
```

Exemplo:

```sql
encode(
    digest(valor_normalizado, 'sha256'),
    'hex'
)
```

A mesma entrada normalizada deverá sempre produzir a mesma Hash Key.

As Business Keys continuarão armazenadas nos Hubs.

A Hash Key é uma chave técnica e não substitui semanticamente a Business Key.

---

## 9. Normalização para geração de Hash Keys

A geração dos hashes deverá seguir uma única regra durante todo o experimento.

Para valores utilizados na geração de Hash Keys, será aplicada a seguinte normalização:

```text
1. converter o valor para texto;
2. remover espaços externos com TRIM;
3. normalizar texto com UPPER;
4. representar NULL com um marcador fixo;
5. concatenar componentes utilizando um separador fixo;
6. aplicar SHA-256.
```

Marcador utilizado para valores NULL:

```text
^^
```

Separador utilizado entre componentes:

```text
||
```

Exemplo conceitual:

```text
order_id = ABC123
customer_unique_id = XYZ789
```

Entrada normalizada:

```text
ABC123||XYZ789
```

A função física responsável pela geração dos hashes deverá ser reutilizada de maneira consistente em todas as cargas.

Para Hubs com Business Key composta por apenas um atributo, a Hash Key será calculada diretamente sobre o valor normalizado da Business Key.

Para Links, a Hash Key será calculada sobre a concatenação determinística dos componentes que identificam o relacionamento.

---

## 10. HashDiff

Os Satellites utilizarão `hashdiff` para detectar alterações em seus atributos descritivos.

O algoritmo utilizado também será:

```text
SHA-256
```

O HashDiff será calculado sobre os atributos pertencentes ao payload do respectivo Satellite.

Exemplo:

```text
sat_order_item

price
freight_value
```

Entrada conceitual:

```text
NORMALIZE(price)
||
NORMALIZE(freight_value)
```

seguida da aplicação de SHA-256.

Quando uma nova carga apresentar:

```text
hashdiff_novo <> hashdiff_existente
```

existe uma alteração no payload do Satellite e uma nova versão poderá ser inserida.

Quando:

```text
hashdiff_novo = hashdiff_existente
```

não existe alteração descritiva a registrar.

O `hashdiff` não identifica a entidade.

Sua finalidade é detectar alterações no conteúdo descritivo do Satellite.

---

## 11. Metadados técnicos

Todas as estruturas do Vault deverão possuir, quando aplicável:

```text
load_timestamp
record_source
```

### 11.1 load_timestamp

Representa o momento em que o registro foi inserido no Data Vault.

Esse timestamp representa o momento técnico da carga, e não necessariamente o momento em que o evento ocorreu no negócio.

### 11.2 record_source

Identifica a origem do registro.

No T0 serão utilizados identificadores consistentes com as tabelas da camada `raw`, por exemplo:

```text
olist.orders
olist.customers
olist.order_items
olist.products
olist.sellers
```

Esses campos são metadados técnicos e não fazem parte dos resultados analíticos.

---

## 12. Não utilização de chaves substitutas sequenciais no Raw Vault

Ao contrário do modelo Kimball, o Raw Vault não utilizará chaves substitutas numéricas sequenciais como identificadores principais das entidades.

Exemplo do modelo Kimball:

```text
customer_sk = 123
product_sk = 918
```

No Data Vault serão utilizadas Hash Keys:

```text
customer_hk
product_hk
order_hk
seller_hk
```

As Business Keys continuam armazenadas nos Hubs:

```text
customer_unique_id
product_id
order_id
seller_id
```

A Hash Key é apenas um identificador técnico determinístico.

---

## 13. Tratamento das datas

O Raw Vault não possuirá uma dimensão de datas.

Os timestamps provenientes da fonte serão preservados em seus Satellites.

No T0:

```text
order_purchase_timestamp
order_delivered_customer_date
order_estimated_delivery_date
```

ficam em:

```text
sat_order
```

A dimensão:

```text
dim_date
```

será criada posteriormente na camada `data_mart`, onde possui finalidade analítica.

---

## 14. Tratamento do status do pedido

O Raw Vault não possuirá:

```text
dim_order_status
```

O atributo:

```text
order_status
```

faz parte de:

```text
sat_order
```

No Data Mart, os valores existentes no Vault serão utilizados para construir:

```text
data_mart.dim_order_status
```

de maneira funcionalmente equivalente ao modelo dimensional Kimball.

---

## 15. Valor calculado do pedido

O atributo:

```text
valor_calculado_pedido
```

não existe diretamente na fonte.

Sua definição analítica é:

```text
SUM(price + freight_value)
GROUP BY order_id
```

Por esse motivo ele não será armazenado no Raw Vault T0.

Os valores de origem permanecem em:

```text
sat_order_item.price
sat_order_item.freight_value
```

`valor_calculado_pedido` será calculado durante a construção do Data Mart e armazenado na estrutura analítica correspondente à `fact_order`.

Pedidos sem itens deverão continuar existindo no Data Mart.

Nesses casos:

```text
valor_calculado_pedido = NULL
```

mantendo a mesma regra utilizada no modelo Kimball.

---

## 16. Tempo de entrega e indicador de atraso

Os seguintes atributos utilizados pelo modelo dimensional:

```text
tempo_entrega_dias
indicador_atraso
```

são derivados.

No Raw Vault serão preservados os timestamps necessários:

```text
order_purchase_timestamp
order_delivered_customer_date
order_estimated_delivery_date
```

Durante a construção do Data Mart será calculado:

```text
tempo_entrega_dias =
order_delivered_customer_date
-
order_purchase_timestamp
```

preservando a fração do dia.

Caso alguma das datas necessárias esteja ausente:

```text
tempo_entrega_dias = NULL
```

O indicador de atraso será definido por:

```text
order_delivered_customer_date
>
order_estimated_delivery_date
```

produzindo:

```text
TRUE
```

quando a entrega ocorreu após a data estimada;

```text
FALSE
```

quando ocorreu dentro ou antes da data estimada;

e:

```text
NULL
```

quando alguma das datas necessárias estiver ausente.

As regras deverão ser idênticas às utilizadas na implementação Kimball.

---

## 17. Data Mart T0

A camada:

```text
data_mart
```

será construída a partir do Data Vault.

Seu objetivo é fornecer um modelo de consumo analítico funcionalmente equivalente ao modelo Kimball T0.

A estrutura prevista é:

```text
data_mart.dim_date
data_mart.dim_customer
data_mart.dim_order_status
data_mart.dim_product
data_mart.dim_seller

data_mart.fact_order
data_mart.fact_order_item
```

Os valores numéricos das surrogate keys do Data Mart não precisam ser iguais aos utilizados no schema `kimball`.

Entretanto, deverão ser equivalentes:

```text
grãos
atributos
medidas
regras de negócio
população analítica
resultados
```

Assim, o caminho arquitetural será:

```text
raw
 ↓
data_vault
 ↓
data_mart
 ↓
Q1 / Q2 / Q3
```

---

## 18. Reconstrução de dim_customer

O Raw Vault possui:

```text
hub_customer
    ↓
customer_unique_id

link_order_customer
    ↓
relacionamento pedido-cliente

sat_order_customer
    ↓
customer_id
customer_zip_code_prefix
customer_city
customer_state
```

A partir dessas estruturas será possível reconstruir:

```text
data_mart.dim_customer
```

com o mesmo grão utilizado no modelo Kimball:

```text
uma linha por customer_id
```

e com os atributos:

```text
customer_id
customer_unique_id
customer_zip_code_prefix
customer_city
customer_state
```

Dessa forma, embora:

```text
hub_customer
```

possua grão:

```text
customer_unique_id
```

o Data Mart poderá possuir grão:

```text
customer_id
```

sem perda da informação necessária ao consumo analítico.

Essa diferença é proposital.

O Hub representa identidade de negócio.

A dimensão representa o contexto necessário para análise.

---

## 19. Reconstrução de dim_product

A dimensão:

```text
data_mart.dim_product
```

será derivada principalmente de:

```text
hub_product
sat_product
```

Seu grão será:

```text
uma linha por product_id
```

No T0, os atributos serão equivalentes aos utilizados no Kimball:

```text
product_id
product_category_name
```

Nenhuma lógica histórica específica de M3 será aplicada neste estado.

---

## 20. Reconstrução de dim_seller

A dimensão:

```text
data_mart.dim_seller
```

será derivada de:

```text
hub_seller
sat_seller
```

Seu grão será:

```text
uma linha por seller_id
```

Com os atributos:

```text
seller_id
seller_zip_code_prefix
seller_city
seller_state
```

---

## 21. Reconstrução de dim_order_status

A dimensão:

```text
data_mart.dim_order_status
```

será derivada dos valores distintos de:

```text
sat_order.order_status
```

Seu grão será:

```text
uma linha por order_status
```

Ela será funcionalmente equivalente à:

```text
kimball.dim_order_status
```

---

## 22. Reconstrução de dim_date

A dimensão:

```text
data_mart.dim_date
```

não existe no Raw Vault.

Ela será criada na camada de consumo a partir do intervalo de datas necessário às informações disponíveis no T0.

No baseline serão consideradas:

```text
order_purchase_timestamp
order_delivered_customer_date
order_estimated_delivery_date
```

A estrutura deverá possuir o mesmo significado analítico da `kimball.dim_date`.

O `date_sk` utilizará o padrão:

```text
YYYYMMDD
```

e será reservado:

```text
date_sk = 0
```

para datas desconhecidas.

---

## 23. Reconstrução de fact_order

A futura:

```text
data_mart.fact_order
```

será derivada principalmente de:

```text
hub_order
sat_order
link_order_customer
sat_order_customer
link_order_item
sat_order_item
```

Seu grão será:

```text
uma linha por order_id
```

Assim como no modelo Kimball.

A estrutura analítica deverá disponibilizar:

```text
order_id

customer_sk
order_status_sk

purchase_date_sk
delivered_date_sk
estimated_delivery_date_sk

order_purchase_timestamp
order_delivered_customer_date
order_estimated_delivery_date

valor_calculado_pedido
tempo_entrega_dias
indicador_atraso
```

As regras utilizadas para construção dessas informações deverão ser equivalentes às utilizadas no modelo Kimball.

`valor_calculado_pedido` será obtido por:

```text
SUM(price + freight_value)
por order_id
```

a partir dos itens preservados no Vault.

---

## 24. Reconstrução de fact_order_item

A futura:

```text
data_mart.fact_order_item
```

será derivada principalmente de:

```text
link_order_item
sat_order_item

hub_order
hub_product
hub_seller

sat_order

link_order_customer
sat_order_customer
```

Seu grão será:

```text
(order_id, order_item_id)
```

Assim como no modelo Kimball.

A estrutura deverá disponibilizar:

```text
order_id
order_item_id

customer_sk
order_status_sk
purchase_date_sk

product_sk
seller_sk

price
freight_value
```

Não será necessário fazer join entre `fact_order_item` e `fact_order` para execução normal das consultas analíticas.

Assim como no modelo Kimball, o contexto necessário ao item será materializado diretamente na fato correspondente.

---

## 25. Equivalência com o modelo Kimball

A comparação não exige igualdade estrutural entre o Raw Vault e o modelo Kimball.

As estruturas possuem finalidades diferentes.

O critério utilizado no experimento será:

```text
mesmas fontes
+
mesmas regras de negócio
+
mesma informação disponível
+
mesmo significado analítico
+
mesmos resultados
```

Arquitetura Kimball:

```text
raw
 ↓
kimball
 ↓
Q1 / Q2 / Q3
```

Arquitetura Data Vault:

```text
raw
 ↓
data_vault
 ↓
data_mart
 ↓
Q1 / Q2 / Q3
```

O Data Mart deverá fornecer um modelo dimensional funcionalmente equivalente ao Kimball.

A equivalência será validada por meio da comparação dos resultados analíticos produzidos pelas duas arquiteturas.

---

## 26. Consultas que deverão ser suportadas

### Q1 — Valor bruto dos itens vendidos

Definição:

```text
SUM(price)
```

considerando somente itens pertencentes a pedidos:

```text
order_status = 'delivered'
```

A população está no grão de item de pedido.

---

### Q2 — Ticket médio calculado dos pedidos

Primeiramente será calculado:

```text
valor_calculado_pedido =
SUM(price + freight_value)
por order_id
```

Posteriormente:

```text
AVG(valor_calculado_pedido)
```

considerando somente:

```text
order_status = 'delivered'
```

A população está no grão de pedido.

---

### Q3 — Desempenho mensal por UF

Grão final:

```text
mês da compra
+
UF do cliente
```

Indicadores:

```text
quantidade_pedidos
quantidade_clientes

quantidade_itens
quantidade_produtos
quantidade_vendedores

valor_bruto_itens
valor_frete

valor_calculado_pedidos
ticket_medio_calculado

tempo_medio_entrega_dias
percentual_entregas_atrasadas
```

Assim como no modelo Kimball, as métricas de pedido e item pertencem a grãos diferentes.

No Data Mart, elas deverão ser agregadas separadamente antes da combinação no grão:

```text
mês + UF
```

para evitar fan-out e duplicação de medidas.

---

## 27. Tratamento de quantidade de clientes

Para Q3, a métrica:

```text
quantidade_clientes
```

não será calculada utilizando `customer_id`.

Será utilizada a identidade lógica:

```text
customer_unique_id
```

portanto:

```text
COUNT(DISTINCT customer_unique_id)
```

Essa regra é a mesma utilizada na implementação Kimball.

Embora `data_mart.dim_customer` possua uma linha por `customer_id`, ela preservará `customer_unique_id` como atributo.

---

## 28. Elementos não antecipados no T0

Para preservar a validade do experimento, o T0 não será preparado antecipadamente para mudanças futuras.

### 28.1 M1 — Pagamentos

Não existem no T0 estruturas específicas para:

```text
payment_sequential
payment_type
payment_installments
payment_value
valor_pago
ticket_medio_pago
```

A fonte:

```text
raw.order_payments
```

também não participa do Data Vault T0.

A modelagem necessária será definida somente durante M1.

---

### 28.2 M2 — Novos timestamps logísticos

Não fazem parte de `sat_order` no T0:

```text
order_approved_at
order_delivered_carrier_date
```

Eles serão incorporados somente quando M2 for aplicada.

---

### 28.3 M3 — Histórico efetivo de categoria

No T0:

```text
sat_product
```

possui somente:

```text
product_category_name
```

Não existem estruturas específicas para:

```text
effective_from
effective_to
categoria_vigente
categoria_atual
```

A solução para temporalidade efetiva será definida durante M3.

O fato de um Satellite permitir armazenar diferentes versões de um atributo ao longo das cargas não resolve automaticamente o requisito de:

```text
categoria vigente na data da venda
```

A distinção entre tempo técnico de carga e tempo de vigência da regra de negócio deverá ser tratada somente quando M3 for implementada.

---

## 29. Critérios de validação do Raw Vault T0

Antes da construção do Data Mart deverão ser validados:

```text
unicidade das Business Keys dos Hubs

quantidade de registros nos Hubs

unicidade dos Links

quantidade de relacionamentos

integridade das referências Hub ↔ Link

consistência das Hash Keys

consistência dos HashDiffs

quantidade de registros nos Satellites

reconciliação dos atributos com raw

reconciliação de price

reconciliação de freight_value

preservação de order_id

preservação de customer_unique_id

preservação de customer_id

preservação de product_id

preservação de seller_id

preservação de order_item_id
```

Nenhuma diferença não explicada entre a camada `raw` e o Raw Vault deverá ser aceita antes da construção do Data Mart.

---

## 30. Critérios de validação do Data Mart T0

Após a construção do Data Mart deverão ser validados:

```text
grão das dimensões

grão de fact_order

grão de fact_order_item

quantidade de pedidos

quantidade de itens

unicidade dos grãos

integridade dimensional

valor bruto dos itens

valor de frete

valor calculado dos pedidos

ticket médio calculado

tempo de entrega

indicador de atraso

Q1

Q2

Q3
```

O objetivo final é comprovar:

```text
Kimball T0
=
Data Mart T0 derivado do Data Vault
```

em termos de resultado analítico.

---

## 31. Valores de controle esperados

O Data Mart T0 deverá reproduzir os resultados já validados na implementação Kimball.

Para pedidos com:

```text
order_status = 'delivered'
```

os principais valores de controle são:

```text
quantidade de pedidos:
96.478

quantidade de itens:
110.197

valor bruto dos itens:
13.221.498,11

valor de frete:
2.198.275,64

valor calculado dos pedidos:
15.419.773,75

ticket médio calculado:
159,8268387611683493
```

Diferenças não explicadas nesses valores indicam falha de equivalência entre as arquiteturas e deverão ser investigadas antes da aplicação das mudanças M1, M2 e M3.

---

## 32. Relação entre os grãos das duas arquiteturas

As estruturas internas das arquiteturas não precisam possuir os mesmos grãos.

No caso do cliente:

```text
KIMBALL

dim_customer
grão = customer_id
```

Enquanto no Raw Vault:

```text
DATA VAULT

hub_customer
grão = customer_unique_id
```

O contexto associado ao `customer_id` é preservado através de:

```text
link_order_customer
+
sat_order_customer
```

Posteriormente:

```text
DATA MART

dim_customer
grão = customer_id
```

Essa transformação é intencional.

O Raw Vault privilegia a representação da identidade e dos relacionamentos do negócio.

O Data Mart privilegia o consumo analítico.

---

## 33. Estado final esperado do T0

Ao final da implementação do Data Vault T0 deverá existir:

```text
RAW
│
├── customers
├── orders
├── order_items
├── products
└── sellers
        │
        ▼
DATA VAULT
│
├── hub_order
├── hub_customer
├── hub_product
├── hub_seller
│
├── link_order_customer
├── link_order_item
│
├── sat_order
├── sat_order_customer
├── sat_product
├── sat_seller
└── sat_order_item
        │
        ▼
DATA MART
│
├── dim_date
├── dim_customer
├── dim_order_status
├── dim_product
├── dim_seller
│
├── fact_order
└── fact_order_item
        │
        ▼
ANÁLISE
│
├── Q1
├── Q2
└── Q3
```

A implementação somente será considerada funcionalmente equivalente ao Kimball T0 após a reconciliação completa dos resultados analíticos.

---

## 34. Resumo das decisões do T0

### Hubs

```text
hub_order
Business Key = order_id

hub_customer
Business Key = customer_unique_id

hub_product
Business Key = product_id

hub_seller
Business Key = seller_id
```

### Links

```text
link_order_customer

Pedido
+
Cliente lógico
```

```text
link_order_item

Pedido
+
Produto
+
Vendedor
+
order_item_id como Dependent Child
```

### Satellites

```text
sat_order
→ atributos do pedido

sat_order_customer
→ ocorrência customer_id e localização no contexto do pedido

sat_product
→ categoria do produto

sat_seller
→ localização do vendedor

sat_order_item
→ price e freight_value
```

### Hashing

```text
algoritmo:
SHA-256

Hash Keys:
identificação técnica determinística de Hubs e Links

HashDiffs:
detecção de alterações nos atributos dos Satellites

representação física prevista:
CHAR(64)
```

### Princípio de comparação

```text
Kimball:

raw
 ↓
modelo dimensional
 ↓
consultas


Data Vault:

raw
 ↓
Raw Vault
 ↓
Data Mart dimensional
 ↓
consultas
```

O objetivo não é fazer as duas arquiteturas possuírem a mesma estrutura interna.

O objetivo é permitir que, partindo das mesmas fontes e das mesmas regras de negócio, ambas produzam resultados analíticos equivalentes antes da aplicação das mudanças M1, M2 e M3.