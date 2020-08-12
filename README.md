# Multi-DoH Server

Warning: This code is highly experimental and I don't recommend running it in production.

The [SkyDroid App](https://github.com/redsolver/skydroid) uses this server to efficiently query a lot of domain names at once in a single request.

It is part of my submission to the [‘Own The Internet’ Hackathon](https://gitcoin.co/hackathon/own-the-internet)

This server requires a [HSD Node](https://github.com/handshake-org/hsd) running locally with `./bin/hsd --rs-port 53`

Enabling Unbound support is recommended.

This server listens on port 8053 and accepts HTTP connections. HTTPS can be enabled using a reverse proxy like Nginx.

## Limitations

- Only TXT Records are supported
- The server currently uses the `dig` command-line tool to run queries against the local resolver and parses the `stdout`. :D

## Example

`POST` to `/multi-dns-query`
```json
{
    "type": 16,
    "names": [
        "example.com",
        "redsolver",
        "papagei"
    ]
}
```

Response
```json
{
    "type": 16,
    "names": {
        "example.com": [],
        "redsolver": [
            "TXT Record 1",
            "TXT Record 2"
        ],
        "papagei": [
            "something something"
        ]
    }
}
```

## How to deploy (if you really want to)

1. Get the [Dart SDK](https://dart.dev/get-dart)
2. `dart2native bin/multi_doh_server.dart` to produce a binary
3. Something like `scp bin/multi_doh_server.exe root@YOUR_SERVER_IP:/root/multi_doh_server/multi_doh_server.exe` to copy the binary to your server
4. Run the binary