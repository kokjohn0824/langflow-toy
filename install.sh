#!/usr/bin/env bash
# 一鍵安裝 bootstrap：clone 本 repo 後執行 scripts/setup.sh
# 使用方式：curl -sL https://raw.githubusercontent.com/<OWNER>/langflow-toy/main/install.sh | bash
# 或指定目錄：curl -sL .../install.sh | bash -s -- ./my-langflow
set -e

REPO_URL="${LANGFLOW_TOY_REPO_URL:-https://github.com/kokjohn0824/langflow-toy.git}"
INSTALL_DIR="${1:-./langflow-toy}"

if ! command -v git >/dev/null 2>&1; then
  echo "錯誤：找不到 git。請先安裝 Git 後再執行此腳本。"
  echo "  macOS: xcode-select --install 或 brew install git"
  exit 1
fi

if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/scripts/setup.sh" ]; then
  echo "已存在專案目錄 $INSTALL_DIR，直接執行 setup..."
  cd "$INSTALL_DIR"
  exec ./scripts/setup.sh
fi

echo "正在 clone 至 $INSTALL_DIR ..."
git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo "正在執行 setup..."
exec ./scripts/setup.sh
