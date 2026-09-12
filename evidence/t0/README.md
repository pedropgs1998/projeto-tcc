# Evidências do estado T0

Este diretório contém as evidências do baseline experimental T0.

## Estrutura

- `diagrams/`: modelos físicos e arquitetura
- `environment/`: versões do ambiente e objetos do banco
- `profile/`: perfil e características dos dados de entrada
- `queries/`: resultados das consultas analíticas Q1, Q2 e Q3
- `validation/`: validações estruturais e equivalência analítica

## Estado T0

Arquitetura A:
RAW → Kimball

Arquitetura B:
RAW → Data Vault → Data Mart

As duas arquiteturas foram validadas utilizando o mesmo contrato analítico.

## Resultado da equivalência

- Q1: diferença = 0
- Q2: diferença = 0
- Q3: 556 grupos em ambas as arquiteturas
- grupos ausentes = 0
- grupos divergentes = 0