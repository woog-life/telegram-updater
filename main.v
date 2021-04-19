module main

import json
import net.http
import os { getenv }
import vgram

struct Data {
    time string
    temperature int
    precise_temperature string [json: preciseTemperature]
}

struct ApiResponse {
    id string
    name string
    data Data
}

fn main() {
    uuid := getenv("LARGE_WOOG_UUID")
    token := getenv("TOKEN")
    notifier_chat_ids := getenv("NOTIFIER_IDS").split(",").map(it.trim_space())
    alert_ids := getenv("TELEGRAM_ALERT_IDS").split(",").map(it.trim_space())

    if uuid == "" {
        eprintln("LARGE_WOOG_UUID is not defined in environment")
        exit(1)
    }
    if token == "" {
        eprintln("TOKEN is not defined in environment")
        exit(1)
    }
    if notifier_chat_ids.len == 0 {
        eprintln("NOTIFIER_IDS is not defined in environment")
        exit(1)
    }
    if alert_ids.len == 0 {
        eprintln("TELEGRAM_ALERT_IDS is not defined in environment")
        exit(1)
    }

    url := "https://api.woog.life/lake/$uuid"
    resp := http.get(url) or {
        eprintln("Failed to get http response")
        exit(1)
    }
    text := resp.text

    content := json.decode(ApiResponse, text) or {
        eprintln("Failed to decode response to ApiResponse object")
        exit(1)
    }

    temperature := content.data.precise_temperature
    bot := vgram.new_bot(token)
    mut results := map[string]int
    for cid in notifier_chat_ids {
        result := bot.send_message({
            chat_id: cid,
            text: "Der Woog hat eine Temperatur von $temperature °C"
        })

        results[cid] = result.from.id
    }

    mut failed := false
    for r_chat_id, message_id in results {
        if message_id == 0 {
            for cid in alert_ids {
                result := bot.send_message({
                    chat_id: cid,
                    text: "failed to send temperature update to: $r_chat_id"
                })

                if result.from.id == 0 {
                    eprintln("Failed to send error to $cid")
                    failed = true
                }
            }
        }
    }

    if failed {
        exit(1)
    }
}
