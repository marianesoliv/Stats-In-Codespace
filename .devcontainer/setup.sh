#!/usr/bin/env bash
set -e

WORKSPACE_DIR="${PWD}"
VENV_DIR="${WORKSPACE_DIR}/.venv"

echo "== Setup: System build deps (Alpine) =="
# dependências necessárias para compilar extensões Python (psutil, etc.)
sudo apk add --no-cache build-base linux-headers python3-dev || true

echo "== Setup: Python / Jupyter (venv) =="

if command -v python3 >/dev/null 2>&1; then
  echo "python3 encontrado."
else
  echo "python3 não encontrado — instalando via apk..."
  sudo apk add --no-cache python3 py3-virtualenv || sudo apk add --no-cache python3
fi

if [ ! -d "${VENV_DIR}" ]; then
  echo "Criando virtualenv em ${VENV_DIR}..."
  python3 -m venv "${VENV_DIR}"
fi

echo "Ativando virtualenv..."
# shellcheck disable=SC1091
. "${VENV_DIR}/bin/activate"

echo "Atualizando pip e instalando jupyter..."
python -m pip install --upgrade pip
python -m pip install --upgrade jupyterlab notebook

echo "== Setup: R / IRkernel (se disponível) =="
if command -v Rscript >/dev/null 2>&1; then
  echo "R encontrado — instalando IRkernel e pacotes comuns..."
  Rscript -e "install.packages('IRkernel', repos='https://cloud.r-project.org')"
  Rscript -e "IRkernel::installspec(user = FALSE)"
  Rscript -e "install.packages(c('ggplot2','dplyr','tidyr','readr','tibble'), repos='https://cloud.r-project.org')"
else
  echo "R não encontrado. Para kernel R, instale R ou use uma imagem baseada em Debian/Ubuntu no devcontainer."
fi

echo "Setup completo."
echo "Para usar:"
echo "  . ${VENV_DIR}/bin/activate"
echo "  python -m jupyter lab --ip=0.0.0.0 --no-browser --port=8888"
