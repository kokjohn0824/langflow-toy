# Langflow Toy

以 Docker 或 uv 一鍵安裝並啟動 [Langflow](https://docs.langflow.org/)，支援 Quickstart、Docker Compose（PostgreSQL）、Flow 打包映像、自訂映像與本機 uv 多種方式。

---

## 一鍵安裝

（請將下方 URL 的 `<OWNER>` 換成實際 GitHub 帳號或組織；若為 fork，改為你的帳號。）

```bash
curl -sL https://raw.githubusercontent.com/<OWNER>/langflow-toy/main/install.sh | bash
```

指定安裝目錄（例如當前目錄下的 `my-langflow`）：

```bash
curl -sL https://raw.githubusercontent.com/<OWNER>/langflow-toy/main/install.sh | bash -s -- ./my-langflow
```

安裝腳本會 clone 本 repo 並執行 `./scripts/setup.sh`，依提示選擇 Docker 或 uv 即可。

---

## 前置需求

- **作業系統**：macOS（目前 setup 腳本僅支援 macOS）
- **Git**：一鍵安裝會使用 `git clone`
- **二選一**：
  - **Docker**：若選 Docker 路線，需已安裝 [Docker](https://docs.docker.com/)（與選用 Docker Compose）
  - **uv**：若選本機路線，腳本會引導安裝 [uv](https://docs.astral.sh/uv/)（建議 Homebrew：`brew install uv`）

---

## 使用說明

1. **執行 setup**  
   首次使用或手動安裝時，在專案根目錄執行：
   ```bash
   ./scripts/setup.sh
   ```
   依提示選擇：
   - **Docker**：再選 [1] Quickstart、[2] Docker Compose、[3] Flow 打包映像、[4] 自訂映像
   - **uv**：本機 Python + uv

2. **啟動／停止／重啟**  
   - **Quickstart**：`./scripts/run.sh`、`./scripts/stop.sh`、`./scripts/restart.sh`  
   - **Docker Compose**：`./scripts/run-docker-compose.sh`、`./scripts/stop-docker-compose.sh`、`./scripts/restart-docker-compose.sh`  
   - **Flow 映像**：`./scripts/run-flow-image.sh`、`./scripts/stop-flow-image.sh`、`./scripts/restart-flow-image.sh`  
   - **自訂映像**：`./scripts/run-custom-image.sh`、`./scripts/stop-custom-image.sh`、`./scripts/restart-custom-image.sh`  
   - **uv 本機**：`./scripts/run.sh`、`./scripts/stop.sh`、`./scripts/restart.sh`

3. **開啟頁面**  
   - **UI**：http://127.0.0.1:7860  
   - **API**：http://127.0.0.1:7860/api  

4. **環境變數（如 OpenAPI / OpenAI API Key）**  
   - **Docker 單一容器**：編輯對應的 `run*.sh`，在 `docker run` 加上 `-e OPENAI_API_KEY=xxx` 或 `--env-file .env`  
   - **Docker Compose**：在 `docker_example/.env` 加入 `OPENAI_API_KEY=xxx` 等變數後重啟  
   - **uv 本機**：啟動前 `export OPENAI_API_KEY=xxx` 或使用 `uv run langflow run --env-file .env`

---

## 可參考資料來源

- [Langflow 官方文件](https://docs.langflow.org/)
- [Langflow Docker 部署](https://docs.langflow.org/deployment-docker)
- [Langflow 環境變數](https://docs.langflow.org/environment-variables)
- [uv 文件](https://docs.astral.sh/uv/)
- [Docker 文件](https://docs.docker.com/)
- [GitHub CLI (gh)](https://cli.github.com/)

---

## 使用 gh 建立本 repo（維護者）

若要在 GitHub 建立此專案並推送：

```bash
gh repo create langflow-toy --public --source=. --remote=origin --description "一鍵安裝 Langflow（Docker / uv）"
# 若已有 remote，可改為：gh repo create langflow-toy --public --source=. --push
```

建立後請：
- 將本 README 與一鍵安裝指令中的 `<OWNER>` 換成實際 GitHub 帳號或組織。
- 將 `install.sh` 內 `REPO_URL` 的 `REPLACE_ME` 改為你的 GitHub 帳號（一鍵安裝的 clone 才會指向正確 repo），再 push。
