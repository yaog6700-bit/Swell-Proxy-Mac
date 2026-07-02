package main

import (
	"fmt"
	"github.com/madeye/baoliandeng/singbox-bridge"
)

func main() {
	jsonStr := `{
        "log": {
            "level": "info",
            "timestamp": true
        },
        "dns": {
            "servers": [
                {"tag": "google", "address": "8.8.8.8", "detour": "direct"},
                {"tag": "local", "address": "local", "detour": "direct"}
            ],
            "rules": [
                {"outbound": "any", "server": "local"},
                {"clash_mode": "direct", "server": "local"},
                {"clash_mode": "global", "server": "google"}
            ],
            "final": "google",
            "strategy": "ipv4_only"
        },
        "inbounds": [
            {
                "type": "socks",
                "tag": "socks-in",
                "listen": "127.0.0.1",
                "listen_port": 7890
            },
            {
                "type": "mixed",
                "tag": "dns-in",
                "listen": "127.0.0.1",
                "listen_port": 1053
            }
        ],
        "outbounds": [
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"},
            {"type": "dns", "tag": "dns-out"}
        ],
        "route": {
            "rules": [
                {"protocol": "dns", "outbound": "dns-out"},
                {"clash_mode": "direct", "outbound": "direct"},
                {"clash_mode": "global", "outbound": "direct"}
            ],
            "final": "direct",
            "auto_detect_interface": true
        },
        "experimental": {
            "clash_api": {
                "external_controller": "127.0.0.1:9090",
                "default_mode": "rule",
                "store_selected": false
            }
        }
    }`

	err := Start(7890, 1053, "127.0.0.1:9090", "", jsonStr)
	if err != nil {
		fmt.Println("START FAILED:", err)
	} else {
		fmt.Println("START SUCCESS!")
	}
}
