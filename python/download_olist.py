import kagglehub
import shutil
from pathlib import Path

download_path = Path(
    kagglehub.dataset_download("olistbr/brazilian-ecommerce")
)

destination = Path("data/raw")
destination.mkdir(parents=True, exist_ok=True)

for file in download_path.glob("*.csv"):
    shutil.copy2(file, destination / file.name)
    print(f"Copiado: {file.name}")

print(f"\nDataset disponível em: {destination.resolve()}")