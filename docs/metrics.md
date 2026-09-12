# Métricas de Avaliação

## 1. Objetivo

Este documento define as métricas que serão utilizadas para avaliar o impacto das mudanças experimentais descritas em `docs/changes.md`.

O objetivo é comparar como as duas abordagens arquiteturais evoluem diante dos mesmos requisitos:

- Modelagem Dimensional de Kimball;
- Data Vault 2.0 com Data Mart dimensional para consumo analítico.

A análise será realizada sempre sobre o impacto provocado por cada mudança em relação ao estado imediatamente anterior.

Assim:

M1 = T1 - T0

M2 = T2 - T1

M3 = T3 - T2

A comparação não deverá se limitar à quantidade de tabelas ou objetos criados.

Serão avaliados três grupos principais de impacto:

1. impacto estrutural;
2. impacto operacional;
3. impacto analítico.

A Mudança 3 também possuirá métricas específicas de histórico e rastreabilidade.

Métricas de performance serão coletadas apenas como informação complementar.

---

# 2. Princípios de medição

As métricas deverão seguir os seguintes princípios.

## 2.1 Comparação por delta

Cada mudança deverá ser comparada com o estado imediatamente anterior.

Elementos introduzidos em mudanças anteriores não deverão ser contabilizados novamente.

Exemplo:

Se uma tabela foi criada em M1 e continua existindo sem alteração em M2, ela não será considerada uma alteração provocada por M2.

---

## 2.2 Separação entre criação e alteração

Criar um novo objeto e modificar um objeto já existente representam tipos diferentes de impacto.

Por isso, deverão ser registrados separadamente:

- objetos criados;
- objetos existentes alterados;
- objetos removidos, caso ocorram;
- objetos preservados sem alteração.

Essa distinção permitirá observar se uma mudança foi absorvida principalmente pela adição de novas estruturas ou pela modificação das estruturas existentes.

---

## 2.3 Separação por camada arquitetural

Quando aplicável, os impactos deverão ser registrados separadamente por camada.

Para Kimball:

- modelo dimensional;
- consumo analítico.

Para Data Vault:

- camada Data Vault;
- Data Mart;
- consumo analítico.

A quantidade total de objetos não deverá ser interpretada isoladamente, pois as arquiteturas possuem estruturas e objetivos diferentes.

---

## 2.4 Equivalência funcional antes da comparação

Uma implementação somente poderá ser utilizada na comparação após produzir resultados funcionalmente equivalentes à outra abordagem.

Diferenças deverão ser investigadas antes da análise de impacto arquitetural.

---

## 2.5 Ausência de pontuação artificial

Não será utilizado um score agregado baseado em pesos arbitrários.

Exemplo de abordagem que não será utilizada:

tabela criada = 2 pontos

join adicional = 1 ponto

reprocessamento = 5 pontos

As métricas serão apresentadas individualmente e analisadas em conjunto.

---

# 3. Impacto estrutural

O impacto estrutural representa quanto da arquitetura existente precisou ser criada, alterada ou atingida por determinada mudança.

---

## 3.1 Objetos criados

Definição:

Quantidade de novos objetos arquiteturais necessários exclusivamente para suportar a mudança.

Devem ser registrados separadamente, quando aplicável:

- tabelas;
- views;
- estruturas auxiliares;
- demais objetos persistentes utilizados pelo modelo.

Exemplo de registro:

tabelas_criadas = 2

views_criadas = 1

---

## 3.2 Objetos existentes alterados

Definição:

Quantidade de objetos já existentes no estado anterior cujo schema, definição ou comportamento estrutural precisou ser modificado por causa da mudança.

Exemplos:

- inclusão de coluna;
- mudança de chave;
- inclusão de controle de versão;
- alteração de uma view;
- alteração da estrutura de uma tabela.

A simples inserção de novos registros em uma tabela cujo schema não mudou não será considerada alteração estrutural.

---

## 3.3 Objetos removidos

Definição:

Quantidade de objetos existentes no estado anterior que deixaram de existir por causa da mudança.

A remoção deverá ser registrada e justificada.

---

## 3.4 Objetos preservados

Definição:

Objetos existentes antes da mudança que continuaram funcionando sem alteração estrutural.

Essa métrica será utilizada para observar quanto da arquitetura anterior permaneceu estável.

---

## 3.5 Taxa de alteração estrutural

Quando aplicável, poderá ser calculada:

taxa_alteracao_estrutural =
objetos_existentes_alterados
/
objetos_existentes_antes_da_mudanca

O valor deverá ser apresentado como percentual.

Exemplo:

2 objetos alterados em um conjunto anterior de 10 objetos:

taxa_alteracao_estrutural = 20%

A taxa não deverá ser interpretada isoladamente como indicador de superioridade.

Ela representa apenas a proporção da estrutura anterior que precisou ser modificada.

---

## 3.6 Taxa de preservação estrutural

Poderá ser calculada:

taxa_preservacao =
objetos_existentes_preservados
/
objetos_existentes_antes_da_mudanca

O objetivo é observar quanto da estrutura anterior permaneceu intacta após a evolução.

---

# 4. Propagação da mudança

Além da quantidade de objetos alterados, será avaliado até onde a mudança se propagou pela arquitetura.

---

## 4.1 Objetos diretamente impactados

Definição:

Objetos que precisam ser criados ou modificados diretamente para representar o novo requisito.

---

## 4.2 Dependências diretas afetadas

Definição:

Objetos que dependem diretamente de um objeto alterado e que precisam ser modificados ou reprocessados devido à mudança.

---

## 4.3 Dependências indiretas afetadas

Definição:

Objetos afetados por propagação através de outras dependências.

Exemplo conceitual:

fonte
  |
  v
objeto A
  |
  v
objeto B
  |
  v
consulta

Se a mudança ocorre em A e exige alterações em B e na consulta:

A = impacto direto

B = dependência direta

consulta = dependência indireta

---

## 4.4 Objetos totais impactados

Definição:

Quantidade total de objetos cujo schema, conteúdo, dependência ou rotina de atualização foi afetado pela mudança.

Um objeto poderá ser considerado impactado mesmo quando seu DDL não for alterado.

---

## 4.5 Profundidade de propagação

Registrar o número de níveis arquiteturais atravessados entre o ponto de entrada da mudança e o consumo analítico.

Exemplo:

RAW
 |
 v
DATA VAULT
 |
 v
DATA MART
 |
 v
QUERY

A profundidade observada seria diferente de uma arquitetura em que a alteração chegasse ao consumo por menos camadas.

Essa medida possui caráter descritivo.

Mais camadas não deverão ser automaticamente interpretadas como pior resultado.

---

# 5. Impacto operacional

O impacto operacional representa as alterações necessárias nos processos de carga e transformação.

---

## 5.1 Rotinas de carga criadas

Definição:

Quantidade de novas rotinas necessárias para carregar ou transformar os dados introduzidos pela mudança.

Uma rotina poderá ser:

- script SQL;
- procedimento de carga;
- etapa independente do pipeline;
- processo equivalente utilizado no projeto.

---

## 5.2 Rotinas existentes alteradas

Definição:

Quantidade de rotinas previamente existentes que precisaram ter sua lógica modificada.

Exemplos:

- inclusão de novo atributo;
- alteração de join;
- alteração de chave;
- tratamento de histórico;
- alteração de ordem de processamento.

---

## 5.3 Rotinas preservadas

Quantidade de rotinas existentes no estado anterior que permaneceram sem modificação após a mudança.

Essa medida complementa a análise de estabilidade do pipeline.

---

## 5.4 Dependências de carga criadas

Registrar novas relações de dependência entre processos.

Exemplo:

processo B passa a depender da conclusão do processo A.

---

## 5.5 Dependências de carga alteradas

Registrar dependências existentes cuja ordem ou relação precisou mudar.

---

# 6. Reprocessamento

O reprocessamento representa quanto do estado previamente carregado precisou ser reconstruído em consequência da mudança.

---

## 6.1 Classificação do reprocessamento

Cada mudança deverá ser classificada como:

- nenhum;
- parcial;
- completo.

### Nenhum

A mudança pode ser incorporada apenas processando dados novos ou estruturas novas.

### Parcial

Parte dos dados previamente existentes precisa ser processada novamente.

### Completo

Todo o conteúdo de uma estrutura relevante precisa ser reconstruído.

---

## 6.2 Objetos reprocessados

Registrar quais tabelas, estruturas ou camadas precisaram ter dados recalculados.

---

## 6.3 Linhas reprocessadas

Quando mensurável, registrar a quantidade de registros previamente existentes que precisaram ser processados novamente.

---

## 6.4 Percentual de reprocessamento

Quando aplicável:

percentual_reprocessado =
linhas_reprocessadas
/
linhas_existentes_antes_da_mudanca

Esse percentual deverá ser calculado separadamente para cada estrutura quando necessário.

---

## 6.5 Justificativa do reprocessamento

Todo reprocessamento deverá registrar seu motivo.

Exemplos:

- necessidade de associar registros históricos a uma nova versão;
- reconstrução de Data Mart;
- inclusão de atributo em dados previamente carregados;
- alteração de regra de negócio.

---

# 7. Impacto no consumo analítico

O impacto analítico representa quanto as consultas existentes precisaram ser adaptadas para consumir o novo estado da arquitetura.

---

## 7.1 Consultas existentes alteradas

Quantidade de consultas previamente existentes cuja implementação precisou ser modificada.

A expectativa previamente definida é:

| Consulta | M1 | M2 | M3 |
|---|---|---|---|
| Q1 | não | não | não |
| Q2 | sim | não | não |
| Q3 | sim | sim | não |
| Consulta histórica M3 | não existe | não existe | criada |

Essa matriz representa o requisito esperado.

A implementação deverá verificar se impactos adicionais foram necessários.

---

## 7.2 Consultas novas

Quantidade de novas consultas necessárias exclusivamente pela mudança.

M3 cria uma consulta específica de validação histórica.

---

## 7.3 Indicadores adicionados

Quantidade de novos indicadores adicionados às consultas existentes.

Exemplo:

M1 adiciona em Q3:

- valor_pago;
- ticket_medio_pago.

M2 adiciona em Q3:

- tempo_medio_aprovacao;
- tempo_medio_preparacao;
- tempo_medio_transporte.

---

## 7.4 Indicadores modificados

Quantidade de indicadores existentes cuja regra de cálculo precisou mudar.

Essa métrica deverá ser diferenciada da simples adição de novos indicadores.

---

# 8. Complexidade estrutural das consultas

A análise das consultas não utilizará quantidade de linhas SQL como principal indicador.

Serão observados elementos estruturais.

---

## 8.1 Estruturas acessadas

Registrar quantas tabelas, views ou estruturas são utilizadas por cada consulta.

---

## 8.2 Joins

Registrar:

- quantidade de joins existentes antes da mudança;
- quantidade de joins após a mudança;
- joins adicionados pelo novo requisito.

O tipo de join poderá ser registrado quando relevante.

---

## 8.3 CTEs e subconsultas

Registrar:

- CTEs existentes;
- CTEs adicionadas;
- subconsultas relevantes adicionadas.

A contagem possui finalidade descritiva e não representa automaticamente maior ou menor qualidade.

---

## 8.4 Pré-agregações

Registrar quando uma consulta exige uma agregação intermediária antes do join ou da agregação final.

Exemplo da M1:

ORDER_ITEMS
    |
    v
agregação por order_id

ORDER_PAYMENTS
    |
    v
agregação por order_id

Somente depois os resultados são combinados.

---

## 8.5 Transições de granularidade

Registrar quantas mudanças de grão são necessárias na construção do resultado.

Exemplo de Q2:

item
  |
  v
pedido
  |
  v
resultado agregado

Exemplo após M1:

pagamento
  |
  v
pedido
  |
  v
resultado agregado

Q3 poderá envolver mais de um fluxo de granularidade.

O objetivo é avaliar a complexidade necessária para produzir o resultado correto, não apenas a quantidade de comandos SQL.

---

## 8.6 Tratamento explícito de fan-out

Registrar se a consulta precisou introduzir lógica específica para evitar multiplicação de registros causada pela combinação de relações 1:N.

Valores possíveis:

- não necessário;
- necessário.

Quando necessário, deverá ser descrita a estratégia utilizada.

---

# 9. Preservação histórica

As métricas desta seção são especialmente relevantes para M3.

---

## 9.1 Versão atual disponível

Verificar se a arquitetura permite recuperar corretamente a categoria corrente de cada produto.

Resultado:

- sim;
- não.

---

## 9.2 Versão histórica disponível

Verificar se categorias anteriores permanecem armazenadas e recuperáveis após a reclassificação.

Resultado:

- sim;
- não.

---

## 9.3 Consulta temporal

Verificar se é possível determinar a categoria vigente no momento da venda.

Resultado:

- sim;
- não.

---

## 9.4 Versões históricas criadas

Registrar a quantidade de novas versões geradas em consequência da M3.

---

## 9.5 Registros históricos preservados

Registrar se as versões anteriores foram mantidas após a alteração.

---

## 9.6 Reprocessamento histórico

Registrar:

- estruturas históricas reprocessadas;
- quantidade de linhas reprocessadas;
- fatos reprocessados, quando aplicável;
- estruturas de consumo reconstruídas.

---

# 10. Rastreabilidade

A rastreabilidade será avaliada como conjunto de capacidades verificáveis.

Para cada arquitetura, registrar se é possível identificar:

| Capacidade | Resultado |
|---|---|
| Fonte original do dado | sim/não |
| Data de carga | sim/não |
| Origem da alteração | sim/não |
| Data efetiva da alteração | sim/não |
| Versão histórica utilizada | sim/não |
| Relação entre registro analítico e origem | sim/não |

Quando a informação estiver disponível apenas em determinada camada, isso deverá ser indicado.

---

# 11. Equivalência funcional

Antes da interpretação das demais métricas, será realizada validação funcional.

A equivalência deverá considerar:

- quantidade de registros;
- somatórios;
- médias;
- percentuais;
- agrupamentos;
- dimensões retornadas;
- tratamento de valores nulos;
- tratamento de anomalias;
- resultados históricos.

---

## 11.1 Tolerância monetária

Para valores monetários poderá ser utilizada tolerância de:

0.01

quando necessária para comparação numérica.

Essa tolerância não deverá ser usada para ocultar divergências existentes na fonte.

---

## 11.2 M1

Validar:

- Q1;
- ticket_medio_pago;
- Q3 após inclusão de pagamentos;
- valor pago por pedido;
- reconciliação financeira.

---

## 11.3 M2

Validar:

- preservação de Q1;
- preservação de Q2;
- indicadores anteriores de Q3;
- tempo_medio_aprovacao;
- tempo_medio_preparacao;
- tempo_medio_transporte.

---

## 11.4 M3

Validar:

- categoria atual;
- categoria vigente na data da venda;
- consulta histórica;
- quantidade de pedidos;
- quantidade de itens;
- valor bruto.

Invariantes dos 10 produtos:

pedidos = 3213

itens = 3814

valor_bruto = 280037.69

---

# 12. Performance

Performance será considerada uma dimensão complementar.

O objetivo principal do experimento é avaliar evolução estrutural, operacional e analítica.

O ambiente utiliza PostgreSQL local e o volume do dataset é limitado, portanto resultados de performance não deverão ser generalizados como benchmarks de mercado.

---

## 12.1 Tempo de carga

Quando viável, registrar:

- tempo de carga incremental;
- tempo de processamento da mudança.

---

## 12.2 Tempo de reprocessamento

Quando houver reprocessamento, registrar sua duração.

---

## 12.3 Tempo das consultas

Registrar, quando possível:

- Q1;
- Q2;
- Q3;
- consulta histórica M3.

As execuções deverão utilizar condições equivalentes entre as arquiteturas.

---

# 13. Amplificação da mudança

Além das métricas individuais, poderá ser observada a relação entre o tamanho da mudança de origem e a quantidade de elementos arquiteturais impactados.

Registrar:

- elementos diretamente introduzidos ou alterados na origem;
- total de objetos arquiteturais impactados.

Exemplo:

M2:

2 novos atributos de origem

provocam alterações em:

N objetos arquiteturais

Essa relação será apresentada de forma descritiva e não como índice de qualidade isolado.

---

# 14. Tabela padrão de coleta

Para cada mudança deverá ser preenchida uma tabela de resultados.

Modelo:

| Métrica | Kimball | Data Vault |
|---|---:|---:|
| Objetos criados |  |  |
| Objetos existentes alterados |  |  |
| Objetos preservados |  |  |
| Taxa de alteração estrutural |  |  |
| Taxa de preservação |  |  |
| Objetos diretamente impactados |  |  |
| Dependências diretas afetadas |  |  |
| Dependências indiretas afetadas |  |  |
| Objetos totais impactados |  |  |
| Profundidade de propagação |  |  |
| Rotinas criadas |  |  |
| Rotinas alteradas |  |  |
| Rotinas preservadas |  |  |
| Dependências de carga criadas |  |  |
| Dependências de carga alteradas |  |  |
| Reprocessamento |  |  |
| Objetos reprocessados |  |  |
| Linhas reprocessadas |  |  |
| Percentual reprocessado |  |  |
| Consultas existentes alteradas |  |  |
| Consultas novas |  |  |
| Indicadores adicionados |  |  |
| Indicadores modificados |  |  |
| Estruturas acessadas pelas consultas |  |  |
| Joins adicionados |  |  |
| CTEs/subconsultas adicionadas |  |  |
| Pré-agregações adicionadas |  |  |
| Transições de granularidade |  |  |
| Tratamento de fan-out |  |  |
| Equivalência funcional |  |  |

M3 deverá adicionar também as métricas específicas de histórico e rastreabilidade.

---

# 15. Registro por camada

Quando aplicável, os valores deverão ser detalhados.

Exemplo para Data Vault:

| Métrica | Data Vault | Data Mart | Total |
|---|---:|---:|---:|
| Tabelas criadas |  |  |  |
| Tabelas alteradas |  |  |  |
| Rotinas criadas |  |  |  |
| Rotinas alteradas |  |  |  |
| Objetos reprocessados |  |  |  |

Para Kimball, deverá ser utilizado detalhamento equivalente quando houver mais de uma camada relevante.

O objetivo é evitar comparações baseadas apenas na soma bruta de objetos.

---

# 16. Matriz de avaliação por mudança

Nem todas as métricas possuem a mesma relevância em todas as mudanças.

A matriz abaixo define o foco principal de cada cenário.

| Dimensão | M1 | M2 | M3 |
|---|---|---|---|
| Estrutura | alta | alta | alta |
| Propagação | alta | alta | alta |
| Carga | alta | alta | alta |
| Reprocessamento | média | média | alta |
| Impacto analítico | alta | alta | média |
| Granularidade | alta | baixa | média |
| Fan-out | alta | baixa | baixa |
| Histórico | baixa | baixa | alta |
| Rastreabilidade | média | média | alta |
| Performance | complementar | complementar | complementar |

Os termos alta, média e baixa desta tabela representam apenas a relevância esperada da dimensão para análise do cenário.

Eles não constituem pontuação nem resultado antecipado.

---

# 17. Interpretação dos resultados

A análise final deverá considerar as métricas em conjunto.

Não serão consideradas conclusões suficientes afirmações isoladas como:

"uma arquitetura criou mais tabelas"

ou:

"uma arquitetura utilizou mais joins".

A interpretação deverá considerar aspectos como:

- quanto da estrutura existente precisou mudar;
- quanto permaneceu preservado;
- até onde a mudança se propagou;
- quanto dado precisou ser reprocessado;
- quanto do pipeline existente precisou ser alterado;
- quanto o consumo analítico precisou mudar;
- como histórico e rastreabilidade foram suportados;
- se os resultados permaneceram funcionalmente corretos.

O objetivo é caracterizar o comportamento das duas abordagens diante da evolução progressiva do mesmo ambiente analítico, e não produzir um ranking absoluto entre Kimball e Data Vault 2.0.