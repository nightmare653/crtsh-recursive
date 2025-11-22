# 📍 Recursive crt.sh Subdomain Enumerator

### A Bash tool for extracting subdomains & wildcard roots using crt.sh — with recursion, retries, and rate limiting

## 🚀 Overview

This script performs **certificate transparency enumeration** using `crt.sh` and automatically:

✅ Queries `crt.sh` for `*.domain.com`
✅ Extracts `name_value` entries via `jq`
✅ Splits results into:

* **Concrete subdomains** → `subs.txt`
* **Wildcard-derived roots** → `wildcards_clean.txt`

✅ Recursively re-queries newly discovered wildcard roots
✅ Avoids duplicate lookups using a `seen` associative array
✅ Saves results in **per-domain folders**
✅ Supports retry logic and rate-limiting

This makes it useful for reconnaissance, bug bounty automation, red teaming, and passive mapping of an organization’s attack surface.

---

## 🧰 Features

### ✅ Fully passive (no DNS / HTTP probing)

### ✅ Recursive wildcard expansion

### ✅ Per-domain output directories

### ✅ Curl retry & timeout handling

### ✅ JSON parsing with jq

### ✅ Skip reruns when data already exists

### ✅ Environment-configurable behavior

---

## 📦 Requirements

Make sure the following binaries are installed:

```bash
curl
jq
```

Install on Debian/Ubuntu/Kali:

```bash
sudo apt install -y curl jq
```

---

## 📄 Input Format

Create a file named `domains.txt` (or any file of your choice):

```
example.com
hackerone.com
bugcrowd.com
# comments and empty lines are ignored
```

---

## ▶️ Usage

### **Basic usage**

```bash
./crt_recursive.sh
```

### **Using a custom input file**

```bash
./crt_recursive.sh targets.txt
```

### **Make it executable (first time only)**

```bash
chmod +x crt_recursive.sh
```

---

## ⚙️ Optional Environment Variables

| Variable             | Default | Purpose                                   |
| -------------------- | ------- | ----------------------------------------- |
| `RATE_LIMIT_SECONDS` | `1`     | Delay between crt.sh requests             |
| `MAX_RETRIES`        | `3`     | Retry count for failed curl attempts      |
| `SKIP_DONE`          | `1`     | Skip domains if `subs.txt` already exists |

### Examples:

#### Slow it down for safety:

```bash
RATE_LIMIT_SECONDS=2 ./crt_recursive.sh
```

#### Force full reprocessing:

```bash
SKIP_DONE=0 ./crt_recursive.sh
```

#### Increase robustness:

```bash
MAX_RETRIES=5 ./crt_recursive.sh
```

#### Combine all:

```bash
RATE_LIMIT_SECONDS=2 MAX_RETRIES=5 SKIP_DONE=0 ./crt_recursive.sh targets.txt
```

---

## 📁 Output Structure

For each domain processed, a directory is created:

```
example.com/
 ├─ subs.txt
 └─ wildcards_clean.txt
```

### `subs.txt` contains:

✅ Non-wildcard resolved subdomains
Example:

```
api.example.com
login.example.com
assets.foo.example.com
```

### `wildcards_clean.txt` contains:

✅ Wildcard-derived roots queued for recursion
Example:

```
foo.example.com
bar.foo.example.com
ae.example.com
```

---

## 🔍 How It Works Internally (Summary)

1. Reads input domains line-by-line
2. Creates per-domain workspace
3. Seeds a queue with the top-level domain
4. Performs BFS-style recursion:

   * queries crt.sh
   * extracts names
   * sends wildcard-derived entries back into queue
5. Dedupe and save results

---

## 🛡 Ethical Usage Notice

This tool is intended for:

✅ penetration testers
✅ bug bounty researchers
✅ asset inventory teams
✅ defensive reconnaissance

**Do not use against systems without authorization.**

---

## 🧪 Next Steps / Recommended Pipeline Integration

After collecting:

```bash
cat */subs.txt | sort -u > all_subs.txt
```


## 👥 Contributors

<a href="https://github.com/Md-Yousuf-Hussain">
  <img src="https://avatars.githubusercontent.com/Md-Yousuf-Hussain" width="60" />
</a>
<a href="https://github.com/nightmare653">
  <img src="https://avatars.githubusercontent.com/nightmare653" width="60" />
</a>

## ⭐ If You Find This Useful

Please **star the repository** — it helps visibility!

---

