# AI chat for bots (mod-ollama-chat)

Builds from 5 Nov 2026 include [mod-ollama-chat](https://github.com/DustinHendrickson/mod-ollama-chat) at commit
`906eb2a`, so bots can answer players in say, party and general chat through an Ollama server (trundle).
This folder holds that commit's config template and characters-database tables; patch night copies the template to
`configs\modules`, creates `mod_ollama_chat.conf` with `OllamaChat.Enable = 0` if there is none (the module's own
default is on), and applies each table file once to the active realm's characters database.

To try it: on trundle set Ollama to listen on the network (`OLLAMA_HOST=0.0.0.0`) and pull a small model. Then in
`mod_ollama_chat.conf` set `OllamaChat.Enable = 1`, `OllamaChat.ApiEndpoint = http://<trundle>:11434` and
`OllamaChat.Model` to that model, and restart the server. Roleplay (`OllamaChat.Roleplay.Enable`) stays off for plain
chat. Turn down the bots' own chatter in `playerbots.conf` (`AiPlayerbot.RandomBotTalk` and friends) if it competes.

The module is AGPL-3.0 (see LICENSE), by Dustin Hendrickson; these files are unchanged copies.
