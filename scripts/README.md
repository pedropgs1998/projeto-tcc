# Scripts de reprodutibilidade

## Arquivos

- `common.sh`: funções e variáveis compartilhadas.

### T0

- `rebuild_t0.sh`: remove os schemas do experimento e reconstrói o estado T0 a partir dos CSVs em `data/raw`.
- `validate_t0.sh`: executa as validações de Kimball, Data Vault, Data Mart e equivalência analítica do estado T0.
- `collect_t0_evidence.sh`: atualiza os outputs em `evidence/t0`.

### T1 / M1

- `apply_t1.sh`: aplica a mudança M1 sobre um estado T0 existente, incorporando a fonte de pagamentos nas arquiteturas Kimball, Data Vault e Data Mart.
- `validate_t1.sh`: executa as validações de Kimball, Data Vault, Data Mart e equivalência analítica do estado T1.
- `collect_t1_evidence.sh`: atualiza os outputs experimentais em `evidence/t1`.
- `rebuild_t1.sh`: reconstrói o estado T0 e, em seguida, aplica e valida a mudança M1 para produzir o estado T1.

## Uso

A partir da raiz do projeto:

```bash
chmod +x scripts/*.sh