# Scripts de reprodutibilidade

## Arquivos

- `common.sh`: funções e variáveis compartilhadas.
- `rebuild_t0.sh`: remove os schemas do experimento e reconstrói o estado T0 a partir dos CSVs em `data/raw`.
- `validate_t0.sh`: executa as validações de Kimball, Data Vault, Data Mart e equivalência analítica.
- `collect_t0_evidence.sh`: atualiza os outputs em `evidence/t0`.

## Uso

A partir da raiz do projeto:

```bash
chmod +x scripts/*.sh

./scripts/rebuild_t0.sh
./scripts/validate_t0.sh
./scripts/collect_t0_evidence.sh
```

`rebuild_t0.sh` é destrutivo para os schemas `raw`, `kimball`, `data_vault`, `data_mart` e `control`.
Ele não remove os arquivos CSV locais.
