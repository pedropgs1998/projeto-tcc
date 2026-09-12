# Modelo Dimensional Kimball — Estado T0

## 1. Objetivo

Este documento define o modelo dimensional da abordagem Kimball no estado inicial T0 do experimento.

O modelo deverá atender exclusivamente aos requisitos definidos em `docs/baseline.md` e servir como base para a aplicação posterior das mudanças descritas em `docs/changes.md`.

O estado T0 deverá suportar corretamente:

- Q1 — Valor bruto dos itens vendidos;
- Q2 — Ticket médio calculado dos pedidos;
- Q3 — Relatório mensal de desempenho por UF.

O modelo não deverá antecipar estruturas necessárias exclusivamente às mudanças M1, M2 ou M3.

---

# 2. Estrutura geral do modelo

O modelo T0 será composto por cinco dimensões e duas tabelas fato.

## Dimensões

- `dim_date`;
- `dim_customer`;
- `dim_order_status`;
- `dim_product`;
- `dim_seller`.

## Fatos

- `fact_order`;
- `fact_order_item`.

As duas tabelas fato possuem granularidades diferentes e representam processos analíticos distintos.

`fact_order`

Grão:

uma linha por pedido.

`fact_order_item`

Grão:

uma linha por item de pedido.

Essa separação evita que medidas existentes no nível de pedido sejam repetidas indevidamente para cada item.

---

# 3. Princípios de modelagem

O modelo seguirá os seguintes princípios:

1. cada fato deverá possuir um grão explicitamente definido;
2. medidas serão armazenadas apenas no grão ao qual pertencem;
3. dimensões compartilhadas entre diferentes fatos deverão possuir significado consistente;
4. as dimensões utilizarão surrogate keys como identificadores internos;
5. identificadores relevantes da origem serão preservados;
6. joins diretos entre tabelas fato não serão utilizados como mecanismo normal de consulta;
7. as fatos compartilharão dimensões conformadas quando necessário;
8. timestamps relevantes serão preservados nas fatos;
9. uma única dimensão de data será reutilizada em diferentes papéis;
10. não será criada `dim_time` no estado T0;
11. não será utilizado Unix Epoch como chave temporal;
12. estruturas destinadas a mudanças futuras não serão criadas antecipadamente;
13. relacionamentos não resolvidos poderão utilizar um registro técnico de dimensão desconhecida;
14. cada tabela possuirá informação mínima de auditoria de carga.

---

# 4. Convenção de chaves

## 4.1 Surrogate Key

As dimensões utilizarão chaves substitutas internas ao Data Warehouse.

Convenção:

`*_sk`

O sufixo `sk` significa:

`Surrogate Key`

Exemplos:

- `customer_sk`;
- `product_sk`;
- `seller_sk`;
- `order_status_sk`;
- `date_sk`.

Essas chaves não possuem significado de negócio.

As tabelas fato deverão utilizá-las como foreign keys para as dimensões.

---

## 4.2 Identificadores de origem

Os identificadores provenientes do dataset Olist serão mantidos utilizando os nomes da origem quando forem relevantes.

Exemplos:

- `customer_id`;
- `customer_unique_id`;
- `product_id`;
- `seller_id`;
- `order_id`;
- `order_item_id`.

Assim:

`product_sk`

representa a chave interna do Data Warehouse.

`product_id`

representa o identificador do produto na origem.

---

# 5. Dimensões conformadas

As seguintes dimensões serão compartilhadas por `fact_order` e `fact_order_item`:

- `dim_date`, no papel de data de compra;
- `dim_customer`;
- `dim_order_status`.

Essas dimensões permitem que métricas provenientes de grãos diferentes sejam analisadas utilizando os mesmos conceitos de negócio.

As seguintes dimensões existem apenas no nível de item:

- `dim_product`;
- `dim_seller`.

Isso ocorre porque um mesmo pedido pode possuir vários produtos e vários vendedores.

---

# 6. Dimensão de Data

## 6.1 Tabela

`dim_date`

## 6.2 Grão

Uma linha por dia do calendário.

## 6.3 Estrutura

- `date_sk`;
- `full_date`;
- `day`;
- `day_of_week`;
- `day_name`;
- `month`;
- `month_name`;
- `quarter`;
- `year`.

## 6.4 Chave

`date_sk` utilizará um valor inteiro no formato:

`YYYYMMDD`

Exemplo:

Data:

`2018-01-17`

Chave:

`20180117`

Não será utilizado Unix Epoch.

---

## 6.5 Role-playing dimension

`dim_date` será utilizada em diferentes papéis.

Na `fact_order`:

- `purchase_date_sk`;
- `delivered_date_sk`;
- `estimated_delivery_date_sk`.

Na `fact_order_item`:

- `purchase_date_sk`.

Todas essas chaves apontarão para:

`dim_date.date_sk`

Não será criada uma `dim_time` no estado T0.

Quando a precisão de hora, minuto ou segundo for necessária, o timestamp original será mantido na fato correspondente.

---

# 7. Dimensão de Cliente

## 7.1 Tabela

`dim_customer`

## 7.2 Fonte

`raw.customers`

## 7.3 Grão

Uma linha por `customer_id`.

## 7.4 Justificativa

O dataset possui:

- `customer_id`;
- `customer_unique_id`.

`customer_id` identifica a ocorrência do cliente utilizada no relacionamento com determinado pedido.

`customer_unique_id` permite identificar a mesma pessoa ao longo de diferentes ocorrências.

Os atributos:

- `customer_zip_code_prefix`;
- `customer_city`;
- `customer_state`;

estão associados ao `customer_id`.

Por esse motivo, a dimensão não será reduzida a uma única linha por `customer_unique_id`.

O grão será:

`customer_id`

e `customer_unique_id` será preservado como atributo analítico.

Isso permite:

- associar cada pedido à localização correspondente;
- calcular quantidade de clientes utilizando `COUNT(DISTINCT customer_unique_id)`.

---

## 7.5 Estrutura

- `customer_sk`;
- `customer_id`;
- `customer_unique_id`;
- `customer_zip_code_prefix`;
- `customer_city`;
- `customer_state`;
- `load_timestamp`.

## 7.6 Chaves

Surrogate Key:

`customer_sk`

Chave de negócio da dimensão:

`customer_id`

Identificador da identidade do cliente:

`customer_unique_id`

---

# 8. Dimensão de Status do Pedido

## 8.1 Tabela

`dim_order_status`

## 8.2 Fonte

Valores distintos de:

`raw.orders.order_status`

## 8.3 Grão

Uma linha por status de pedido.

## 8.4 Estrutura

- `order_status_sk`;
- `order_status`;
- `load_timestamp`.

## 8.5 Chaves

Surrogate Key:

`order_status_sk`

Chave de negócio:

`order_status`

---

## 8.6 Valores observados na origem

Entre os valores presentes no dataset estão:

- `delivered`;
- `shipped`;
- `canceled`;
- `unavailable`;
- `invoiced`;
- `processing`;
- `created`;
- `approved`.

O baseline utiliza:

`order_status = 'delivered'`

para definir a população principal das consultas analíticas.

---

# 9. Dimensão de Produto

## 9.1 Tabela

`dim_product`

## 9.2 Fonte

`raw.products`

## 9.3 Grão

Uma linha por `product_id`.

## 9.4 Estrutura

- `product_sk`;
- `product_id`;
- `product_category_name`;
- `load_timestamp`.

## 9.5 Chaves

Surrogate Key:

`product_sk`

Chave de negócio:

`product_id`

---

## 9.6 Histórico em T0

No estado T0 será mantida apenas uma versão de cada produto.

Não serão criados antecipadamente:

- `valid_from`;
- `valid_to`;
- `current_flag`;
- múltiplas versões da mesma chave de negócio;
- mecanismos SCD Type 2.

Esses elementos somente serão introduzidos caso sejam necessários durante M3.

---

# 10. Dimensão de Vendedor

## 10.1 Tabela

`dim_seller`

## 10.2 Fonte

`raw.sellers`

## 10.3 Grão

Uma linha por `seller_id`.

## 10.4 Estrutura

- `seller_sk`;
- `seller_id`;
- `seller_zip_code_prefix`;
- `seller_city`;
- `seller_state`;
- `load_timestamp`.

## 10.5 Chaves

Surrogate Key:

`seller_sk`

Chave de negócio:

`seller_id`

---

# 11. Fato de Pedido

## 11.1 Tabela

`fact_order`

## 11.2 Processo representado

Representa informações e medidas existentes no nível de pedido.

## 11.3 Grão

Uma linha por pedido.

Formalmente:

`1 registro = 1 order_id`

`order_id` deverá ser único na tabela.

---

## 11.4 Dimensão degenerada

`order_id` será mantido diretamente na tabela fato.

Não será criada uma `dim_order` apenas para representar esse identificador.

Nesse contexto, `order_id` funciona como uma dimensão degenerada.

---

## 11.5 Estrutura

### Identificação

- `order_id`.

### Chaves dimensionais

- `customer_sk`;
- `order_status_sk`;
- `purchase_date_sk`;
- `delivered_date_sk`;
- `estimated_delivery_date_sk`.

### Valores temporais

- `order_purchase_timestamp`;
- `order_delivered_customer_date`;
- `order_estimated_delivery_date`.

### Medidas e indicadores

- `valor_calculado_pedido`;
- `tempo_entrega_dias`;
- `indicador_atraso`.

### Auditoria

- `load_timestamp`.

---

# 12. Medidas da fact_order

## 12.1 Valor calculado do pedido

Nome:

`valor_calculado_pedido`

Definição:

SUM(price + freight_value)
GROUP BY order_id

A origem do cálculo é:

`raw.order_items`

A medida deverá aparecer apenas uma vez por pedido.

---

## 12.2 Tempo de entrega

Nome:

`tempo_entrega_dias`

Definição conceitual:

`order_delivered_customer_date - order_purchase_timestamp`

A medida deverá ser calculada somente quando as datas necessárias estiverem disponíveis.

O cálculo deverá preservar a precisão temporal disponível na origem.

---

## 12.3 Indicador de atraso

Nome:

`indicador_atraso`

Regra:

`order_delivered_customer_date > order_estimated_delivery_date`

Resultado:

- `TRUE`, quando a entrega ocorreu após a data estimada;
- `FALSE`, quando a entrega ocorreu dentro ou antes da data estimada;
- `NULL`, quando as informações necessárias não estiverem disponíveis.

---

# 13. Fato de Item de Pedido

## 13.1 Tabela

`fact_order_item`

## 13.2 Processo representado

Representa cada item pertencente a um pedido.

## 13.3 Grão

Uma linha por item de pedido.

Formalmente:

`1 registro = 1 combinação (order_id, order_item_id)`

A combinação:

`(order_id, order_item_id)`

deverá ser única.

---

## 13.4 Identificadores

Serão preservados:

- `order_id`;
- `order_item_id`.

`order_id` funcionará também como dimensão degenerada.

---

## 13.5 Estrutura

### Identificação

- `order_id`;
- `order_item_id`.

### Chaves dimensionais

- `customer_sk`;
- `order_status_sk`;
- `purchase_date_sk`;
- `product_sk`;
- `seller_sk`.

### Medidas

- `price`;
- `freight_value`.

### Auditoria

- `load_timestamp`.

---

# 14. Medidas da fact_order_item

## 14.1 Preço do item

Nome:

`price`

Origem:

`raw.order_items.price`

Representa o valor do item no pedido.

A medida pertence ao grão de item.

---

## 14.2 Valor de frete do item

Nome:

`freight_value`

Origem:

`raw.order_items.freight_value`

Representa o valor de frete associado ao item.

A medida pertence ao grão de item.

---

# 15. Relacionamentos das tabelas fato

## 15.1 fact_order

Relaciona-se com:

- `dim_customer`;
- `dim_order_status`;
- `dim_date` no papel de compra;
- `dim_date` no papel de entrega;
- `dim_date` no papel de entrega estimada.

Estrutura conceitual:

`fact_order.customer_sk`
→ `dim_customer.customer_sk`

`fact_order.order_status_sk`
→ `dim_order_status.order_status_sk`

`fact_order.purchase_date_sk`
→ `dim_date.date_sk`

`fact_order.delivered_date_sk`
→ `dim_date.date_sk`

`fact_order.estimated_delivery_date_sk`
→ `dim_date.date_sk`

---

## 15.2 fact_order_item

Relaciona-se com:

- `dim_customer`;
- `dim_order_status`;
- `dim_date` no papel de compra;
- `dim_product`;
- `dim_seller`.

Estrutura conceitual:

`fact_order_item.customer_sk`
→ `dim_customer.customer_sk`

`fact_order_item.order_status_sk`
→ `dim_order_status.order_status_sk`

`fact_order_item.purchase_date_sk`
→ `dim_date.date_sk`

`fact_order_item.product_sk`
→ `dim_product.product_sk`

`fact_order_item.seller_sk`
→ `dim_seller.seller_sk`

---

# 16. Dimensões compartilhadas entre as fatos

As duas fatos compartilham:

- `dim_customer`;
- `dim_order_status`;
- `dim_date`, no papel de data da compra.

Matriz:

| Dimensão | fact_order | fact_order_item |
|---|---:|---:|
| dim_customer | sim | sim |
| dim_order_status | sim | sim |
| dim_date — compra | sim | sim |
| dim_date — entrega | sim | não |
| dim_date — entrega estimada | sim | não |
| dim_product | não | sim |
| dim_seller | não | sim |

A presença de `customer_sk`, `order_status_sk` e `purchase_date_sk` em ambas as fatos é intencional.

---

# 17. Por que order_status_sk também existe na fact_order_item

Q1 e parte de Q3 utilizam métricas provenientes de `fact_order_item`, mas consideram apenas pedidos com status:

`delivered`

Se `order_status_sk` existisse apenas em `fact_order`, seria necessário realizar um join fato-a-fato para filtrar os itens.

Esse comportamento será evitado.

Por isso:

`fact_order_item.order_status_sk`

referencia diretamente:

`dim_order_status`

permitindo filtrar:

`order_status = 'delivered'`

sem consultar `fact_order`.

---

# 18. Redundância dimensional intencional

Algumas informações originalmente obtidas através de `orders` também serão carregadas em `fact_order_item`.

Entre elas:

- `customer_sk`;
- `order_status_sk`;
- `purchase_date_sk`.

Essa redundância é intencional no modelo dimensional.

Ela permite responder diretamente perguntas como:

- valor vendido por UF;
- quantidade de itens por mês;
- produtos vendidos por estado;
- vendedores envolvidos em pedidos entregues;

sem utilizar `fact_order` como intermediária.

Esses atributos são contexto dimensional.

Medidas pertencentes ao pedido, como:

- `tempo_entrega_dias`;
- `valor_calculado_pedido`;

não serão repetidas na `fact_order_item`.

---

# 19. Relação entre fact_order e fact_order_item

Na origem existe:

ORDER
  |
  | 1
  |
  | N
  v
ORDER_ITEM

No modelo dimensional, não será criada uma foreign key entre:

`fact_order`

e:

`fact_order_item`.

As duas tabelas possuem grãos distintos.

A relação de negócio continua identificável através de:

`order_id`

presente nas duas fatos.

Entretanto, consultas analíticas deverão evitar joins diretos entre as fatos.

Quando for necessário combinar métricas dos dois processos, cada fato deverá primeiro ser agregada ao mesmo grão analítico.

---

# 20. Registro desconhecido

As dimensões deverão reservar a surrogate key:

`0`

para representar um membro desconhecido ou não resolvido.

Exemplo conceitual:

`product_sk = 0`

Atributos descritivos poderão utilizar:

`DESCONHECIDO`

quando apropriado.

Caso uma foreign key não possa ser resolvida durante a carga:

`fact_order_item.product_sk = 0`

em vez de manter uma referência inválida.

Para `dim_date`:

`date_sk = 0`

poderá representar ausência de data.

A utilização desse registro não deverá ocultar problemas de qualidade.

Ocorrências deverão continuar sendo verificáveis durante as validações da carga.

---

# 21. Auditoria

Todas as dimensões e fatos possuirão:

`load_timestamp`

Esse campo representa o momento em que o registro foi carregado na respectiva estrutura dimensional.

Não serão adicionados ao Kimball T0 mecanismos específicos de Data Vault, como:

- Hash Key;
- HashDiff;
- Satellite;
- Link;
- mecanismos de auditoria próprios da metodologia Data Vault.

Isso preserva a separação entre as duas abordagens comparadas.

---

# 22. Mapeamento RAW → Kimball

## raw.customers

Destino principal:

`dim_customer`

Também será utilizado na resolução de `customer_sk` durante a carga das fatos.

---

## raw.orders

Destinos e usos:

`fact_order`

e apoio à construção de:

`fact_order_item`

para obtenção de:

- `customer_sk`;
- `order_status_sk`;
- `purchase_date_sk`.

Também fornece os valores distintos utilizados para:

`dim_order_status`

---

## raw.order_items

Destino principal:

`fact_order_item`

Também será utilizado para calcular:

`fact_order.valor_calculado_pedido`

---

## raw.products

Destino:

`dim_product`

---

## raw.sellers

Destino:

`dim_seller`

---

# 23. Atendimento à Q1

## Q1 — Valor bruto dos itens vendidos

Origem principal:

`fact_order_item`

Relacionamento utilizado:

`fact_order_item.order_status_sk`
→ `dim_order_status.order_status_sk`

Filtro:

`dim_order_status.order_status = 'delivered'`

Cálculo:

SUM(fact_order_item.price)

Não será necessário consultar `fact_order`.

---

# 24. Atendimento à Q2

## Q2 — Ticket médio calculado dos pedidos

Origem:

`fact_order`

Filtro:

`dim_order_status.order_status = 'delivered'`

Medida utilizada:

`valor_calculado_pedido`

Cálculo:

AVG(valor_calculado_pedido)

Como existe apenas uma linha por pedido, pedidos com múltiplos itens não receberão peso adicional no cálculo.

---

# 25. Atendimento à Q3

## Q3 — Relatório mensal de desempenho por UF

Q3 utiliza informações provenientes de dois grãos distintos.

Por esse motivo, as duas fatos serão agregadas separadamente antes da combinação final.

---

## 25.1 Métricas no grão de pedido

Origem:

`fact_order`

Dimensões:

- `dim_date`;
- `dim_customer`;
- `dim_order_status`.

Filtro:

`order_status = 'delivered'`

Agrupamento:

- mês da compra;
- `customer_state`.

Indicadores:

- `quantidade_pedidos`;
- `quantidade_clientes`;
- `valor_calculado_pedidos`;
- `ticket_medio_calculado`;
- `tempo_medio_entrega_dias`;
- `percentual_entregas_atrasadas`.

`quantidade_clientes` deverá utilizar:

COUNT(DISTINCT customer_unique_id)

---

## 25.2 Métricas no grão de item

Origem:

`fact_order_item`

Dimensões:

- `dim_date`;
- `dim_customer`;
- `dim_order_status`;
- `dim_product`;
- `dim_seller`.

Filtro:

`order_status = 'delivered'`

Agrupamento:

- mês da compra;
- `customer_state`.

Indicadores:

- `quantidade_itens`;
- `quantidade_produtos`;
- `quantidade_vendedores`;
- `valor_bruto_itens`;
- `valor_frete`.

---

## 25.3 Combinação dos resultados

Cada conjunto deverá ser agregado primeiro ao mesmo grão analítico:

`mês + customer_state`

Somente depois os resultados serão combinados.

Fluxo:

FACT_ORDER
    |
    v
agregação por mês + UF
    |
    v
MÉTRICAS_PEDIDO


FACT_ORDER_ITEM
    |
    v
agregação por mês + UF
    |
    v
MÉTRICAS_ITEM


MÉTRICAS_PEDIDO
        +
MÉTRICAS_ITEM
        |
        v
Q3

Essa abordagem evita que múltiplos itens de um mesmo pedido provoquem duplicação de:

- quantidade de pedidos;
- valor calculado por pedido;
- tempo de entrega;
- indicador de atraso.

---

# 26. Requisitos não antecipados em T0

## 26.1 M1 — Pagamentos

Não serão criadas estruturas analíticas para:

- `order_payments`;
- `payment_type`;
- `payment_installments`;
- `payment_value`;
- `valor_pago_pedido`;
- `ticket_medio_pago`.

---

## 26.2 M2 — Novos atributos logísticos

Não serão disponibilizados analiticamente em T0:

- `order_approved_at`;
- `order_delivered_carrier_date`.

Também não serão calculados:

- `tempo_medio_aprovacao`;
- `tempo_medio_preparacao`;
- `tempo_medio_transporte`.

---

## 26.3 M3 — Histórico de categoria

`dim_product` não possuirá mecanismos específicos de preservação histórica em T0.

Não existirão antecipadamente:

- versões múltiplas do produto;
- intervalos de validade;
- indicador de versão corrente;
- SCD Type 2.

---

# 27. Modelo consolidado

## dim_date

Grão:

uma linha por data.

Chave:

`date_sk`

---

## dim_customer

Grão:

uma linha por `customer_id`.

Surrogate Key:

`customer_sk`

Chave de negócio:

`customer_id`

Identidade do cliente:

`customer_unique_id`

---

## dim_order_status

Grão:

uma linha por status.

Surrogate Key:

`order_status_sk`

Chave de negócio:

`order_status`

---

## dim_product

Grão:

uma linha por `product_id`.

Surrogate Key:

`product_sk`

Chave de negócio:

`product_id`

---

## dim_seller

Grão:

uma linha por `seller_id`.

Surrogate Key:

`seller_sk`

Chave de negócio:

`seller_id`

---

## fact_order

Grão:

uma linha por `order_id`.

Dimensões:

- cliente;
- status;
- data de compra;
- data de entrega;
- data estimada de entrega.

Medidas principais:

- `valor_calculado_pedido`;
- `tempo_entrega_dias`;
- `indicador_atraso`.

---

## fact_order_item

Grão:

uma linha por `(order_id, order_item_id)`.

Dimensões:

- cliente;
- status;
- data de compra;
- produto;
- vendedor.

Medidas:

- `price`;
- `freight_value`.

---

# 28. Estado da definição

Este documento representa a definição inicial do modelo Kimball no estado T0.

A implementação poderá revelar necessidades técnicas de ajuste.

Alterações serão permitidas desde que:

- preservem o grão definido das fatos;
- mantenham os requisitos de `baseline.md`;
- não antecipem M1, M2 ou M3;
- não sejam realizadas para favorecer artificialmente uma das arquiteturas;
- sejam registradas quando representarem uma mudança relevante no modelo.

Após a implementação, Q1, Q2 e Q3 deverão ser validadas antes da evolução para T1.