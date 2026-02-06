#!/usr/bin/env bash
set -e

# --- 1. 檢查作業系統：僅支援 macOS ---
if [ "$(uname -s)" != "Darwin" ]; then
  echo "此腳本僅供 macOS 使用。"
  exit 1
fi

# --- 2. 定位專案根目錄（依腳本所在目錄，與執行時 cwd 無關）---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
echo "專案根目錄: $PROJECT_ROOT"

# --- 2.5 選擇安裝方式：Docker 或 uv（本機）---
echo ""
echo "請選擇安裝方式："
echo "  [1] Docker 版本（使用 docker run，不需安裝 Python/uv）"
echo "  [2] 本機 uv 版本（使用 uv + Python，可自訂依賴）"
echo ""
read -r -p "是否使用 Docker 版本安裝？(y/N) " use_docker
case "$use_docker" in
  [yY]|[yY][eE][sS]|1)
    USE_DOCKER=1
    ;;
  *)
    USE_DOCKER=0
    ;;
esac

if [ "$USE_DOCKER" = "1" ]; then
  # --- Docker 路線：先檢查 docker ---
  if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤：找不到 docker。請先安裝 Docker Desktop 或 Docker Engine。"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "錯誤：Docker 未運行或無權限。請啟動 Docker 後再試。"
    exit 1
  fi

  # --- Docker 子選單：四種安裝／啟動方式 ---
  echo ""
  echo "請選擇 Docker 安裝／啟動方式："
  echo "  [1] Quickstart（單一容器，預設）"
  echo "  [2] Docker Compose（PostgreSQL + 持久化）"
  echo "  [3] 將 Flow 打包成映像（自訂 flow JSON）"
  echo "  [4] 自訂 Langflow 映像（自訂程式碼／依賴）"
  echo ""
  read -r -p "請輸入 1～4（預設 1）: " docker_choice
  docker_choice="${docker_choice:-1}"

  case "$docker_choice" in
    1)
      # --- Quickstart：單一容器（detach）---
      mkdir -p "$PROJECT_ROOT/scripts"
      RUN_SH="$PROJECT_ROOT/scripts/run.sh"
      STOP_SH="$PROJECT_ROOT/scripts/stop.sh"
      RESTART_SH="$PROJECT_ROOT/scripts/restart.sh"
      cat > "$RUN_SH" << 'RUN_SH_EOF'
#!/usr/bin/env bash
# 背景啟動。要傳入 API key 等：可加 -e OPENAI_API_KEY=xxx 或 --env-file .env
set -e
docker run -d --name langflow-quickstart -p 7860:7860 langflowai/langflow:latest
RUN_SH_EOF
      cat > "$STOP_SH" << 'STOP_SH_EOF'
#!/usr/bin/env bash
set -e
docker stop langflow-quickstart 2>/dev/null || true
docker rm langflow-quickstart 2>/dev/null || true
STOP_SH_EOF
      cat > "$RESTART_SH" << 'RESTART_SH_EOF'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop.sh"
exec "$SCRIPT_DIR/run.sh"
RESTART_SH_EOF
      chmod +x "$RUN_SH" "$STOP_SH" "$RESTART_SH"
      echo ""
      echo "Langflow Docker（Quickstart）已就緒。"
      echo "  - 啟動: ./scripts/run.sh（背景執行）"
      echo "  - 停止: ./scripts/stop.sh"
      echo "  - 重新啟動: ./scripts/restart.sh"
      echo "  - 開啟頁面: UI http://127.0.0.1:7860  |  API http://127.0.0.1:7860/api"
      echo "  - 環境變數（如 OPENAI_API_KEY）：編輯 run.sh 在 docker run 加 -e OPENAI_API_KEY=xxx 或 --env-file .env"
      echo ""
      echo "正在啟動（背景）..."
      "$RUN_SH"
      echo "已於背景啟動。請開啟 http://127.0.0.1:7860"
      ;;
    2)
      # --- Docker Compose：PostgreSQL + 持久化 ---
      if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        echo "錯誤：找不到 docker compose 或 docker-compose。請安裝 Docker Compose 後再試。"
        exit 1
      fi
      DOCKER_EXAMPLE="$PROJECT_ROOT/docker_example"
      mkdir -p "$DOCKER_EXAMPLE"
      cat > "$DOCKER_EXAMPLE/docker-compose.yml" << 'COMPOSE_EOF'
services:
  langflow:
    image: langflowai/langflow:latest
    pull_policy: always
    ports:
      - "7860:7860"
    depends_on:
      - postgres
    env_file:
      - .env
    environment:
      - LANGFLOW_DATABASE_URL=postgresql://langflow:langflow@postgres:5432/langflow
      - LANGFLOW_CONFIG_DIR=/app/langflow
    volumes:
      - langflow-data:/app/langflow

  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: langflow
      POSTGRES_PASSWORD: langflow
      POSTGRES_DB: langflow
    ports:
      - "5432:5432"
    volumes:
      - langflow-postgres:/var/lib/postgresql/data

volumes:
  langflow-postgres:
  langflow-data:
COMPOSE_EOF
      cat > "$DOCKER_EXAMPLE/.env.example" << 'ENV_EOF'
# Database credentials
POSTGRES_USER=langflow
POSTGRES_PASSWORD=langflow
POSTGRES_DB=langflow

# Langflow configuration
LANGFLOW_DATABASE_URL=postgresql://langflow:langflow@postgres:5432/langflow
LANGFLOW_CONFIG_DIR=/app/langflow

# 供 flow 使用的 API key（可選，Langflow 會從環境變數讀取）
# OPENAI_API_KEY=sk-xxx
# LANGCHAIN_API_KEY=xxx
ENV_EOF
      if [ ! -f "$DOCKER_EXAMPLE/.env" ]; then
        cp "$DOCKER_EXAMPLE/.env.example" "$DOCKER_EXAMPLE/.env"
      fi
      RUN_COMPOSE="$PROJECT_ROOT/scripts/run-docker-compose.sh"
      STOP_COMPOSE="$PROJECT_ROOT/scripts/stop-docker-compose.sh"
      RESTART_COMPOSE="$PROJECT_ROOT/scripts/restart-docker-compose.sh"
      cat > "$RUN_COMPOSE" << RUN_COMPOSE_SCRIPT
#!/usr/bin/env bash
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"
cd "\$PROJECT_ROOT/docker_example"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi
RUN_COMPOSE_SCRIPT
      cat > "$STOP_COMPOSE" << RUN_STOP_SCRIPT
#!/usr/bin/env bash
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\$SCRIPT_DIR/.." && pwd)"
cd "\$PROJECT_ROOT/docker_example"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose down
else
  docker-compose down
fi
RUN_STOP_SCRIPT
      cat > "$RESTART_COMPOSE" << RUN_RESTART_SCRIPT
#!/usr/bin/env bash
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
"\$SCRIPT_DIR/stop-docker-compose.sh"
exec "\$SCRIPT_DIR/run-docker-compose.sh"
RUN_RESTART_SCRIPT
      chmod +x "$RUN_COMPOSE" "$STOP_COMPOSE" "$RESTART_COMPOSE"
      echo ""
      echo "Langflow Docker Compose 已就緒。"
      echo "  - 啟動: ./scripts/run-docker-compose.sh（背景）"
      echo "  - 停止: ./scripts/stop-docker-compose.sh"
      echo "  - 重新啟動: ./scripts/restart-docker-compose.sh"
      echo "  - 開啟頁面: UI http://127.0.0.1:7860  |  API http://127.0.0.1:7860/api"
      echo "  - 環境變數：複製 docker_example/.env.example 為 .env，加入 OPENAI_API_KEY 等後重啟。"
      echo ""
      echo "正在啟動（背景）..."
      "$RUN_COMPOSE"
      echo "已於背景啟動。請開啟 http://127.0.0.1:7860"
      ;;
    3)
      # --- Package flow as image ---
      mkdir -p "$PROJECT_ROOT/flows"
      mkdir -p "$PROJECT_ROOT/scripts"
      cat > "$PROJECT_ROOT/Dockerfile.flow" << 'DOCKERFILE_FLOW_EOF'
FROM langflowai/langflow:latest
RUN mkdir /app/flows
COPY *.json /app/flows/
ENV LANGFLOW_LOAD_FLOWS_PATH=/app/flows
DOCKERFILE_FLOW_EOF
      RUN_FLOW="$PROJECT_ROOT/scripts/run-flow-image.sh"
      STOP_FLOW="$PROJECT_ROOT/scripts/stop-flow-image.sh"
      RESTART_FLOW="$PROJECT_ROOT/scripts/restart-flow-image.sh"
      cat > "$RUN_FLOW" << 'RUN_FLOW_SCRIPT'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
# Build context 為 flows/，請在 flows/ 內放入至少一個 .json。要傳 API key 可加 -e OPENAI_API_KEY=xxx 或 --env-file .env
docker build -f Dockerfile.flow -t langflow-flow:latest flows/
docker run -d --name langflow-flow -p 7860:7860 langflow-flow:latest
RUN_FLOW_SCRIPT
      cat > "$STOP_FLOW" << 'STOP_FLOW_SCRIPT'
#!/usr/bin/env bash
set -e
docker stop langflow-flow 2>/dev/null || true
docker rm langflow-flow 2>/dev/null || true
STOP_FLOW_SCRIPT
      cat > "$RESTART_FLOW" << 'RESTART_FLOW_SCRIPT'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop-flow-image.sh"
exec "$SCRIPT_DIR/run-flow-image.sh"
RESTART_FLOW_SCRIPT
      chmod +x "$RUN_FLOW" "$STOP_FLOW" "$RESTART_FLOW"
      echo ""
      echo "Langflow「Flow 打包成映像」已就緒。"
      echo "  - 請將 flow 的 JSON 放到 flows/ 目錄（至少一個 .json 後再執行 build）。"
      echo "  - 啟動: ./scripts/run-flow-image.sh（背景）"
      echo "  - 停止: ./scripts/stop-flow-image.sh"
      echo "  - 重新啟動: ./scripts/restart-flow-image.sh"
      echo "  - 開啟頁面: UI http://127.0.0.1:7860  |  API http://127.0.0.1:7860/api"
      echo "  - 環境變數：編輯 run-flow-image.sh 在 docker run 加 -e OPENAI_API_KEY=xxx 或 --env-file .env"
      echo ""
      echo "正在啟動（若 flows/ 尚無 .json，build 會失敗）..."
      if "$RUN_FLOW" 2>/dev/null; then
        echo "已於背景啟動。請開啟 http://127.0.0.1:7860"
      else
        echo "啟動失敗或略過。請在 flows/ 放入至少一個 .json 後執行 ./scripts/run-flow-image.sh"
      fi
      ;;
    4)
      # --- Custom Langflow image ---
      mkdir -p "$PROJECT_ROOT/scripts"
      cat > "$PROJECT_ROOT/Dockerfile.custom" << 'DOCKERFILE_CUSTOM_EOF'
# 自訂 Langflow 映像範本
# 請依需求修改：自訂檔案路徑、COPY 來源、以及 RUN 中的 site-packages 路徑。
# 參考：https://docs.langflow.org/deployment-docker#customize-the-langflow-docker-image

FROM langflowai/langflow:latest

WORKDIR /app

# 複製自訂程式碼（請改為你的路徑與檔案）
COPY src/lfx/src/lfx/components/helpers/memory.py /tmp/memory.py

RUN python -c "import site; print(site.getsitepackages()[0])" > /tmp/site_packages.txt

RUN SITE_PACKAGES=$(cat /tmp/site_packages.txt) && \
    mkdir -p "$SITE_PACKAGES/langflow/components/helpers" && \
    cp /tmp/memory.py "$SITE_PACKAGES/langflow/components/helpers/"

RUN SITE_PACKAGES=$(cat /tmp/site_packages.txt) && \
    find "$SITE_PACKAGES" -name "*.pyc" -delete && \
    find "$SITE_PACKAGES" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

EXPOSE 7860

CMD ["python", "-m", "langflow", "run", "--host", "0.0.0.0", "--port", "7860"]
DOCKERFILE_CUSTOM_EOF
      RUN_CUSTOM="$PROJECT_ROOT/scripts/run-custom-image.sh"
      STOP_CUSTOM="$PROJECT_ROOT/scripts/stop-custom-image.sh"
      RESTART_CUSTOM="$PROJECT_ROOT/scripts/restart-custom-image.sh"
      cat > "$RUN_CUSTOM" << 'RUN_CUSTOM_SCRIPT'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
# 要傳 API key 可加 -e OPENAI_API_KEY=xxx 或 --env-file .env
docker build -f Dockerfile.custom -t langflow-custom:latest .
docker run -d --name langflow-custom -p 7860:7860 langflow-custom:latest
RUN_CUSTOM_SCRIPT
      cat > "$STOP_CUSTOM" << 'STOP_CUSTOM_SCRIPT'
#!/usr/bin/env bash
set -e
docker stop langflow-custom 2>/dev/null || true
docker rm langflow-custom 2>/dev/null || true
STOP_CUSTOM_SCRIPT
      cat > "$RESTART_CUSTOM" << 'RESTART_CUSTOM_SCRIPT'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop-custom-image.sh"
exec "$SCRIPT_DIR/run-custom-image.sh"
RESTART_CUSTOM_SCRIPT
      chmod +x "$RUN_CUSTOM" "$STOP_CUSTOM" "$RESTART_CUSTOM"
      echo ""
      echo "Langflow「自訂映像」範本已就緒。"
      echo "  - 請編輯 Dockerfile.custom 與自訂程式碼後，執行: ./scripts/run-custom-image.sh"
      echo "  - 啟動: ./scripts/run-custom-image.sh（背景）"
      echo "  - 停止: ./scripts/stop-custom-image.sh"
      echo "  - 重新啟動: ./scripts/restart-custom-image.sh"
      echo "  - 開啟頁面: UI http://127.0.0.1:7860  |  API http://127.0.0.1:7860/api"
      echo "  - 環境變數：編輯 run-custom-image.sh 在 docker run 加 -e OPENAI_API_KEY=xxx 或 --env-file .env"
      echo "  - 文件: https://docs.langflow.org/deployment-docker#customize-the-langflow-docker-image"
      echo ""
      echo "正在啟動（若尚未準備自訂程式碼，build 可能失敗）..."
      if "$RUN_CUSTOM" 2>/dev/null; then
        echo "已於背景啟動。請開啟 http://127.0.0.1:7860"
      else
        echo "啟動失敗或略過。請編輯 Dockerfile.custom 後執行 ./scripts/run-custom-image.sh"
      fi
      ;;
    *)
      echo "無效選項。請重新執行腳本並輸入 1～4。"
      exit 1
      ;;
  esac
  exit 0
fi

# --- 3. 以下為 uv 路線：檢查並安裝 uv（須在建立/使用 pyproject 前就緒）---
# 官方安裝腳本需要 curl
if ! command -v curl >/dev/null 2>&1; then
  echo "錯誤：找不到 curl。請先安裝 Xcode 指令列工具：xcode-select --install"
  exit 1
fi

ensure_uv() {
  uv_ok() {
    command -v uv >/dev/null 2>&1 && uv --version >/dev/null 2>&1
  }
  if uv_ok; then
    echo "已找到 uv: $(command -v uv) ($(uv --version 2>/dev/null | head -1))"
    return 0
  fi

  # 預設優先使用 Homebrew 安裝
  if command -v brew >/dev/null 2>&1; then
    echo "正在以 Homebrew 安裝 uv (brew install uv)..."
    if brew install uv 2>/dev/null; then
      export PATH="$(brew --prefix)/bin:${PATH}"
      if uv_ok; then
        echo "uv 已安裝: $(command -v uv) ($(uv --version 2>/dev/null | head -1))"
        return 0
      fi
    fi
    echo "無法透過 Homebrew 取得 uv，或安裝後仍無法使用。"
  else
    echo "未偵測到 Homebrew，無法使用 brew install uv。"
  fi

  # 詢問是否改為使用官方安裝腳本直接安裝
  echo ""
  read -r -p "是否要改為使用官方安裝腳本直接安裝 uv？(y/N) " answer
  case "$answer" in
    [yY]|[yY][eE][sS])
      echo "正在以官方安裝腳本安裝 uv..."
      curl -LsSf https://astral.sh/uv/install.sh | sh
      export PATH="${HOME}/.local/bin:${PATH}"
      ;;
    *)
      echo "已略過。請手動安裝 uv 後再執行此腳本。"
      echo "  - 使用 Homebrew: brew install uv"
      echo "  - 或官方安裝: curl -LsSf https://astral.sh/uv/install.sh | sh"
      exit 1
      ;;
  esac

  if ! command -v uv >/dev/null 2>&1; then
    echo "錯誤：uv 安裝後仍無法找到。請將 \$HOME/.local/bin 加入 PATH 後重試。"
    exit 1
  fi
  if ! uv --version >/dev/null 2>&1; then
    echo "錯誤：uv 已安裝但無法正常執行，請檢查環境。"
    exit 1
  fi
  echo "uv 已安裝: $(command -v uv) ($(uv --version 2>/dev/null | head -1))"
}

ensure_uv
# 確保後續步驟都能用到 uv（若剛安裝）
export PATH="${HOME}/.local/bin:${PATH}"
if command -v brew >/dev/null 2>&1; then
  export PATH="$(brew --prefix)/bin:${PATH}"
fi

# 若尚無 pyproject.toml，則初始化專案（完全乾淨狀態可啟動）
if [ ! -f "$PROJECT_ROOT/pyproject.toml" ]; then
  echo "未發現 pyproject.toml，正在初始化專案..."
  uv init --no-readme
  uv add langflow
  echo "已建立 pyproject.toml 並加入 langflow。"
fi

# --- 4. 檢查並安裝 Python（依 .python-version 或預設 3.12）---
PY_VERSION="3.12"
if [ -f "$PROJECT_ROOT/.python-version" ]; then
  PY_VERSION="$(cat "$PROJECT_ROOT/.python-version" | tr -d '[:space:]')"
fi
echo "使用 Python 版本: $PY_VERSION"
echo "確保 Python $PY_VERSION 已安裝 (uv python install)..."
uv python install "$PY_VERSION"

# --- 5. 安裝依賴（uv sync）---
echo "正在同步依賴 (uv sync)..."
uv sync

# --- 6. 建立建議目錄與 run.sh / stop.sh / restart.sh（若缺失）---
mkdir -p "$PROJECT_ROOT/flows"

RUN_SH="$PROJECT_ROOT/scripts/run.sh"
STOP_SH="$PROJECT_ROOT/scripts/stop.sh"
RESTART_SH="$PROJECT_ROOT/scripts/restart.sh"
if [ ! -f "$RUN_SH" ]; then
  echo "建立 scripts/run.sh..."
  cat > "$RUN_SH" << 'RUN_SH_EOF'
#!/usr/bin/env bash
set -e

export LANGFLOW_PORT=7860
export LANGFLOW_HOST=127.0.0.1

uv run langflow run
RUN_SH_EOF
  chmod +x "$RUN_SH"
fi
if [ ! -f "$STOP_SH" ]; then
  echo "建立 scripts/stop.sh（本機 uv 用，依 port 7860 結束行程）..."
  cat > "$STOP_SH" << 'STOP_SH_EOF'
#!/usr/bin/env bash
# 僅供本機 uv 使用：結束佔用 7860 的行程
set -e
lsof -ti:7860 | xargs kill 2>/dev/null || true
STOP_SH_EOF
  chmod +x "$STOP_SH"
fi
if [ ! -f "$RESTART_SH" ]; then
  echo "建立 scripts/restart.sh..."
  cat > "$RESTART_SH" << 'RESTART_SH_EOF'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop.sh"
exec "$SCRIPT_DIR/run.sh"
RESTART_SH_EOF
  chmod +x "$RESTART_SH"
fi

# --- 7. 結束：輸出說明 ---
echo ""
echo "Langflow 環境已就緒。"
echo "  - 啟動: ./scripts/run.sh  或  uv run langflow run"
echo "  - 停止: ./scripts/stop.sh"
echo "  - 重新啟動: ./scripts/restart.sh"
echo "  - 開啟頁面: UI http://127.0.0.1:7860  |  API http://127.0.0.1:7860/api"
echo "  - 環境變數：啟動前 export OPENAI_API_KEY=xxx 或建立 .env 並 uv run langflow run --env-file .env"
