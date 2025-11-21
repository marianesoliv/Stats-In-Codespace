#!/usr/bin/env bash
set -euo pipefail

echo "[setup] Starting post-create setup..."

# Ativa task_delayacct no kernel (tenta sysctl, fallback para write em /proc)
# isso é para o clickhouse
if command -v sudo >/dev/null 2>&1; then
  sudo sysctl -w kernel.task_delayacct=1 >/dev/null 2>&1 || sudo sh -c 'echo 1 > /proc/sys/kernel/task_delayacct' >/dev/null 2>&1 || true
else
  sysctl -w kernel.task_delayacct=1 >/dev/null 2>&1 || sh -c 'echo 1 > /proc/sys/kernel/task_delayacct' >/dev/null 2>&1 || true
fi

# Ensure ~/.local/bin is on PATH for user-installed Python scripts
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  echo "[setup] Added $HOME/.local/bin to PATH"
fi

# Ensure Python pip tooling is up-to-date
echo "[setup] Upgrading pip, setuptools, and wheel..."
python3 -m pip install --no-cache-dir --upgrade --break-system-packages pip setuptools wheel || \
  python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel || true

# Install Python requirements if present
if [[ -f "/workspaces/Stats-In-Codespace/requirements.txt" ]]; then
  echo "[setup] Installing Python requirements from requirements.txt..."
  python3 -m pip install --no-cache-dir --break-system-packages -r /workspaces/Stats-In-Codespace/requirements.txt || \
    python3 -m pip install --no-cache-dir -r /workspaces/Stats-In-Codespace/requirements.txt
else
  echo "[setup] No requirements.txt found; skipping Python dependency install."
fi

# Ensure a usable Jupyter Python kernel for the current user
echo "[setup] Ensuring Jupyter Python kernel is available for user..."
python3 - <<'PY'
import json, os, subprocess, sys
try:
    # Try installing a user kernel spec; ignore if it already exists
    subprocess.run([
        sys.executable, "-m", "ipykernel", "install",
        "--user", "--name=python3", "--display-name=Python 3"
    ], check=False)
except Exception as e:
    print(f"[setup] ipykernel install skipped/failed: {e}")
PY

# R setup: per-user library path and selective package install
echo "[setup] Configuring R user library and installing common packages (idempotent)..."
mkdir -p "$HOME/R/library"
if ! grep -q "R_LIBS_USER" "$HOME/.Renviron" 2>/dev/null; then
  echo 'R_LIBS_USER="~/R/library"' >> "$HOME/.Renviron"
fi

Rscript - <<'RS'
options(repos = c(CRAN = "https://cloud.r-project.org"))
dir.create(Sys.getenv("R_LIBS_USER"), recursive = TRUE, showWarnings = FALSE)
.libPaths(Sys.getenv("R_LIBS_USER"))

pkgs <- c("IRkernel", "languageserver", "ggplot2", "dplyr", "tidyr")
installed <- rownames(installed.packages())
to_install <- setdiff(pkgs, installed)
if (length(to_install)) {
  message("[setup:R] Installing: ", paste(to_install, collapse = ", "))
  install.packages(to_install, Ncpus = 2)
} else {
  message("[setup:R] All target packages already installed.")
}

ok <- FALSE
try({ IRkernel::installspec(user = FALSE); ok <- TRUE }, silent = TRUE)
if (!ok) {
  try({ IRkernel::installspec(user = TRUE); ok <- TRUE }, silent = TRUE)
}
if (!ok) {
  message("[setup:R] Warning: Could not register IRkernel; it may already be registered.")
} else {
  message("[setup:R] IRkernel registration ensured.")
}
RS

echo "[setup] Done."
