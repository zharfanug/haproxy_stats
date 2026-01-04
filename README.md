# HAProxy Stats CLI Tool

`haproxy_stats` is a simple command-line tool to check the status of HAProxy backend servers. It allows you to quickly view which servers are UP or DOWN and provides information about connection issues.

## Features

- Display all HAProxy backend servers with their status.
- Filter servers that are UP or DOWN.
- Show server IP, mode, downtime, and reason for being down.

## Installation

Download the latest version and move it to your `$PATH`:

Using `wget`:

```bash
wget -O /usr/local/bin/haproxy_stats https://raw.githubusercontent.com/zharfanug/haproxy_stats/latest/haproxy_stats.sh && chmod +x /usr/local/bin/haproxy_stats
```
Using `curl`:
```bash
curl -o /usr/local/bin/haproxy_stats https://raw.githubusercontent.com/zharfanug/haproxy_stats/latest/haproxy_stats.sh && chmod +x /usr/local/bin/haproxy_stats
```

## Usage
```lua
Usage: haproxy_stats [OPTION]

Options:
  -h, --help    Show this help message
  -d, --down    Show HAProxy servers that are DOWN
  -u, --up      Show HAProxy servers that are UP
```
Examples

Show all servers:
```bash
haproxy_stats
```

Show only servers that are DOWN:
```bash
haproxy_stats -d
```