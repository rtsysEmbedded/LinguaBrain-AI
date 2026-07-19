# German Vocabulary MVP — Non-Production Reference Experiment

> **Status:** Reference only; not part of the LinguaBrain production application, package graph, release, or default CI.
>
> **Owner role:** Software Architect
>
> **Purpose:** Validate a narrow Telegram/Excel → AI/SQLite → optional Anki workflow.
>
> **Retirement gate:** M2 exit review.
>
> **Governing decision:** [ADR-001](../../decisions/ADR-001-Repository-Package-and-Module-Layout.md)

This code does not implement the approved LinguaBrain domain, learning, validation, review, privacy, or persistence contracts. Production code must not import it or depend on its API/database schema. Generated records remain private and linguistically unverified.

## Local setup guide

This MVP receives a German word from Telegram or Excel, looks in SQLite, asks a configured AI only when necessary, saves the result, and can export it to Anki.

The default Telegram setup is **local long polling**. n8n asks Telegram for new messages every five seconds. The local n8n UI binds only to `127.0.0.1`; no public IP address, domain, tunnel, or public/LAN listener is required.

## Choose a Telegram mode

| Mode | Main workflow | Public address | When to use it |
| --- | --- | --- | --- |
| **Local polling — default** | [telegram-workflow.json](n8n/telegram-workflow.json) | No | Personal/local computer |
| **Webhook — optional future mode** | [telegram-webhook-workflow.json](n8n/telegram-webhook-workflow.json) | Yes, HTTPS | Immediate event delivery or a public server |

Do not activate both workflows with the same bot. Telegram allows either long polling (`getUpdates`) or a webhook, not both at once. [Telegram's official FAQ](https://core.telegram.org/bots/faq)

## Local architecture

```text
Telegram app
    ↑  ↓  outbound HTTPS requests only
n8n on your Mac — polls Telegram every 5 seconds
    ↓
FastAPI on your Mac
    ↓
SQLite + LM Studio/Ollama on your Mac
    ↓
Optional AnkiConnect on your Mac
```

Telegram itself is an internet service, so internet access is necessary. However, no service needs to be reachable from the internet. LM Studio/Ollama, FastAPI, SQLite, n8n, and Anki remain local.

## What you need

- A Mac with internet and a Telegram account.
- Python 3.9 or newer: run `python3 --version`.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) for n8n. Open it and wait until Docker is running.
- **One** AI provider. LM Studio or Ollama is recommended for local AI.
- Optional: [Anki](https://apps.ankiweb.net/) desktop for Anki export.

Open Terminal from **Applications → Utilities → Terminal**. Keep separate Terminal windows open for the model, FastAPI, and n8n.

## Find the project folder once

The project folder does **not** have a fixed path. Its location is wherever you saved or cloned this repository.

To open Terminal in the correct folder on macOS:

1. Open Finder and find the `vocabulary-mvp` folder.
2. In Terminal, type `cd` followed by one space.
3. Drag the `vocabulary-mvp` folder from Finder into the Terminal window.
4. Press Enter, then run:

   ```bash
   pwd
   ```

The result must end with `/vocabulary-mvp`. All remaining FastAPI commands in this guide assume that Terminal is already in this folder. Do not copy a hard-coded path from this document.

## 1. Start a local AI model

### LM Studio

1. Install [LM Studio](https://lmstudio.ai/).
2. Download and load a German-capable instruct/chat model.
3. Open **Developer** and start the local server; the normal URL is `http://localhost:1234/v1`.
4. Find its model ID:

   ```bash
   curl http://localhost:1234/v1/models
   ```

   Copy the `id` value.

### Ollama

1. Install [Ollama](https://ollama.com/download).
2. Run:

   ```bash
   ollama pull llama3.1
   ollama serve
   ```

Keep `ollama serve` running. Its normal API URL is `http://localhost:11434/v1`.

## 2. Install and test the vocabulary API

In a Terminal opened in the `vocabulary-mvp` folder:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Open `.env` in a text editor.

- With LM Studio, set `LMSTUDIO_MODEL` to the model ID you copied.
- With Ollama, leave `OLLAMA_MODEL=llama3.1` or change it to a downloaded model.
- Keep OpenAI and Anthropic keys blank if you want local-only AI.

Start FastAPI:

```bash
uvicorn app:app --reload --port 8000
```

In another Terminal:

```bash
curl http://localhost:8000/health
```

Expected response:

```json
{"status":"ok"}
```

Test the AI before Telegram:

```bash
curl -X POST http://localhost:8000/lookup \
  -H 'Content-Type: application/json' \
  -d '{"word":"bewältigen","provider":"lmstudio","add_to_anki":false}'
```

Change `lmstudio` to `ollama` if you use Ollama. The second request for the same word should contain `"cached": true`.

## 3. Create a Telegram bot

1. In Telegram, open **@BotFather**.
2. Send `/newbot`.
3. Choose a display name, for example `LinguaBrain Vocabulary`.
4. Choose a username, for example `my_linguabrain_vocab_bot`. It must end in `bot`.
5. Copy the access token BotFather gives you.
6. Open the new bot's `https://t.me/...` link and press **Start**.

The token controls the bot. Do not put it in Git, screenshots, or workflow files. If it leaks, use BotFather's `/token` command to replace it. Telegram bots cannot begin a private chat; the user must press Start first.

## 4. Install and start n8n in local polling mode

Create persistent storage for n8n:

```bash
docker volume create n8n_data
```

First, load the token into this Terminal without printing it:

```bash
read -s "TELEGRAM_BOT_TOKEN?Paste Telegram bot token: "
export TELEGRAM_BOT_TOKEN
```

Now run n8n:

```bash
docker run --rm -it \
  --name linguabrain-n8n \
  -p 127.0.0.1:5678:5678 \
  -e GENERIC_TIMEZONE="Europe/Berlin" \
  -e TZ="Europe/Berlin" \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_CONCURRENCY_PRODUCTION_LIMIT=1 \
  -e EXECUTIONS_DATA_SAVE_ON_SUCCESS=none \
  -e EXECUTIONS_DATA_SAVE_ON_ERROR=none \
  -e EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=false \
  -e EXECUTIONS_DATA_PRUNE=true \
  -e EXECUTIONS_DATA_MAX_AGE=24 \
  -e EXECUTIONS_DATA_PRUNE_MAX_COUNT=100 \
  -e N8N_SECURE_COOKIE=false \
  -e N8N_BLOCK_ENV_ACCESS_IN_NODE=false \
  -e TELEGRAM_BOT_TOKEN \
  -e VOCABULARY_API_URL="http://host.docker.internal:8000" \
  -e VOCABULARY_AI_PROVIDER="lmstudio" \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n
```

Open [http://localhost:5678](http://localhost:5678). On first use, create the n8n owner account.

Important settings:

- `TELEGRAM_BOT_TOKEN` lets n8n call Telegram's local-polling API.
- `VOCABULARY_API_URL` lets the Docker container call FastAPI on your Mac. Do **not** use `localhost:8000` inside Docker.
- `VOCABULARY_AI_PROVIDER` is `lmstudio` or `ollama`.
- `N8N_CONCURRENCY_PRODUCTION_LIMIT=1` prevents overlapping polling runs from processing the same Telegram update twice.
- The execution-data settings disable saved success, error, and manual payloads and keep pruning enabled as defense in depth. This matters because Telegram Bot API request URLs contain the bot token. See the [official n8n execution environment-variable reference](https://docs.n8n.io/hosting/configuration/environment-variables/executions/).
- No `WEBHOOK_URL` is present because polling does not use a public webhook.

For Linux, add this before the final Docker image:

```bash
--add-host=host.docker.internal:host-gateway \
```

The persistent Docker volume and port 5678 follow the [official n8n Docker installation](https://docs.n8n.io/hosting/installation/docker/).

## 5. Import and activate the polling workflow

1. In n8n, choose **Import from File**.
2. Select [n8n/telegram-workflow.json](n8n/telegram-workflow.json).
3. Click **Save**.
4. Turn the workflow **Active**.

No Telegram credential must be created in n8n for this workflow. The bot token is read from the `TELEGRAM_BOT_TOKEN` environment variable supplied to Docker.

The polling workflow:

```text
Every 5 seconds
    ↓
Telegram getUpdates
    ↓
Store the last update offset locally in n8n
    ↓
FastAPI /lookup
    ↓
Telegram sendMessage
```

On its **first active run**, it records the newest existing Telegram update and intentionally ignores old pending messages. After activation, send a new word to the bot. The offset is stored in n8n workflow static data, so it survives normal n8n restarts.

Do not use **Execute Workflow** as the main test for offset persistence. Activate the workflow and let the Schedule Trigger run in production mode.

## 6. Test Telegram

Keep these three services running:

1. LM Studio server or `ollama serve`.
2. FastAPI on port 8000.
3. n8n Docker on port 5678.

Send this to the bot:

```text
bewältigen
```

Within about five seconds, you should receive:

```text
📘 bewältigen
Verb | B2
🇮🇷 از عهده برآمدن، مدیریت کردن
🇬🇧 to cope with, to manage
💬 Sie konnte die Situation gut bewältigen.
او توانست شرایط را به‌خوبی مدیریت کند.
Perfekt: hat bewältigt
⚠️ AI · تأیید زبانی نشده
```

The AI warning means the JSON structure was validated, but the linguistic facts have not been reviewed by a human or dictionary.

## 7. Import words from Excel

Create an `.xlsx` or `.xlsm` file with a column named exactly `word`:

| word |
| --- |
| bewältigen |
| der Aufwand |
| zuverlässig |

With FastAPI running:

```bash
curl -X POST http://localhost:8000/import \
  -F "file=@words.xlsx" \
  -F "provider=lmstudio" \
  --output import_results.csv
```

The result CSV has `word`, `status`, and `error`. Empty rows are ignored, existing words are skipped, and one failure does not stop later words.

## 8. Optional Anki export

1. Install and open [Anki](https://apps.ankiweb.net/).
2. Go to **Tools → Add-ons → Get Add-ons**.
3. Enter the AnkiConnect code `2055492159`.
4. Restart Anki.
5. Create a deck named `German Vocabulary`, or change `ANKI_DECK` in `.env`.

Keep the `Basic` note type with `Front` and `Back` fields, or change `ANKI_MODEL`, `ANKI_FRONT_FIELD`, and `ANKI_BACK_FIELD` in `.env`.

Check AnkiConnect:

```bash
curl localhost:8765 -X POST -d '{"action":"version","version":6}'
```

Export an existing word:

```bash
curl -X POST http://localhost:8000/anki/bewältigen
```

AnkiConnect normally listens on local port 8765 and this project never changes Anki's internal database. [AnkiConnect documentation](https://github.com/amikey/anki-connect)

## Optional future mode: webhook

The old event-based method is kept in [n8n/telegram-webhook-workflow.json](n8n/telegram-webhook-workflow.json).

Use it only when you want Telegram to push messages immediately to n8n. It requires a public HTTPS URL, for example a Cloudflare Tunnel or a domain/reverse proxy:

1. Deactivate the polling workflow.
2. Run a tunnel to local n8n:

   ```bash
   cloudflared tunnel --url http://localhost:5678
   ```

3. Restart n8n with `WEBHOOK_URL="https://YOUR-PUBLIC-URL/"`.
4. Import `telegram-webhook-workflow.json`.
5. Create one Telegram credential from the BotFather token and assign it to its Telegram Trigger and all Telegram send nodes.
6. Activate the webhook workflow.

When returning to local polling, deactivate the webhook workflow first. Telegram's `getUpdates` API does not work while a webhook is registered. [Telegram Bot API](https://core.telegram.org/bots/api)

## Daily start checklist

### Default local polling

1. Start LM Studio or `ollama serve`.
2. Open a Terminal in the `vocabulary-mvp` folder using **Find the project folder once** above, then start FastAPI:

   ```bash
   source .venv/bin/activate
   uvicorn app:app --reload --port 8000
   ```

3. In the same Terminal, load `TELEGRAM_BOT_TOKEN` using the `read -s` command above, then start n8n with the local-polling Docker command.
4. Confirm the polling workflow remains Active.
5. Open Anki only if you need Anki export.

### Optional webhook

1. Start the model and FastAPI.
2. Start the HTTPS tunnel.
3. Start n8n with the current tunnel URL in `WEBHOOK_URL`.
4. Activate only the webhook workflow.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| FastAPI health check fails | Start FastAPI from the `vocabulary-mvp` folder on port 8000. |
| `could not reach lmstudio` | Start LM Studio's server and check `LMSTUDIO_BASE_URL` and `LMSTUDIO_MODEL`. |
| Telegram does not reply in polling mode | Check that the polling workflow is Active, n8n was started with `TELEGRAM_BOT_TOKEN`, and you sent the word **after** activation. |
| Bot replies twice | Do not import/activate the same polling workflow twice. Keep only one n8n instance running. |
| Bot ignores a message sent before activation | Expected: the first polling run consumes old pending messages. Send a new word after activation. |
| n8n cannot call FastAPI | Use `http://host.docker.internal:8000` on Mac, not `localhost:8000`. |
| Telegram says a webhook is set | Deactivate the webhook workflow before using polling. |
| Anki export fails | Open Anki, check AnkiConnect on port 8765, and confirm deck/model/field names in `.env`. |

## Privacy and safety

- `.env` and the Telegram token are secrets. Do not commit or share them.
- Telegram Bot API request URLs include the token. Do not copy, screenshot, export, or share live execution details. Stop n8n and rotate the token with BotFather if execution data or diagnostics containing a request URL are exposed.
- `vocabulary.db` stores your saved vocabulary content locally.
- Local polling exposes the n8n UI only on `127.0.0.1:5678`; it creates no LAN/public listener and requires no public address.
- LM Studio and Ollama process AI locally. OpenAI and Anthropic process requested words through their cloud APIs.
- This is a vocabulary ingestion/cache MVP. AI records are `schema_validated_unverified`, not a verified dictionary or complete Learning Engine.
