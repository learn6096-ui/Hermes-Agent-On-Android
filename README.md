<div align="center">
<img width="1145" height="196" alt="hermesbanner" src="https://github.com/user-attachments/assets/68e4a2a7-74d2-4089-9e5f-6f0a46fe54f5" />


# *☤ Hermes Agent for Android (Termux)*

### *Run a Self-Evolving AI Assistant on Your Phone — Python 3.13 Compatible*

[![License: MIT](https://img.shields.io/badge/License-MIT-9146ff.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Termux](https://img.shields.io/badge/Termux-Android-ff6b6b.svg?style=for-the-badge)](https://termux.com/)
[![Python](https://img.shields.io/badge/Python-3.13-3776ab.svg?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Version](https://img.shields.io/badge/version-v0.10.0-4ecdc4.svg?style=for-the-badge)](https://github.com/NousResearch/hermes-agent)

**Transform your Android device into a powerful, learning AI assistant**
</div>

## ✨ What is Hermes Agent?

> **Hermes Agent** is an open-source, self-evolving AI framework developed by [Nous Research](https://github.com/NousResearch/hermes-agent). It's like having **Jarvis in your pocket** - an AI that learns, adapts, and grows smarter with every interaction.

<div align="center">

| 🧠 Self-Learning | 🔄 Cross-Platform | 💾 Persistent Memory | 🛠️ 70+ Tools |
|:----------------:|:------------------:|:-------------------:|:-------------:|
| Gets smarter over time | Works on 16+ apps | Remembers your preferences | Execute complex tasks |

</div>

---

## ⏱️ Installation takes ~5-10 minutes - Grab a coffee! ☕

## Installation Preview:
```mermaid
graph LR
    A[📱 Open Termux] --> B[📋 Copy Command]
    B --> C[⚡ Paste & Run]
    C --> D[🔄 Auto-Install]
    D --> E[✅ Ready to Use!]
```

---

# 🚀 **One-Line Installation (Recommended)**

### **Copy and paste this command in Termux:**

```bash
curl -fsSL https://raw.githubusercontent.com/learn6096-ui/Hermes-Agent-On-Android/main/nous_hermes_agent_install.sh | bash
```

> [!NOTE]
> This uses the most robust installer (`nous_hermes_agent_install.sh`) with full error handling, Ubuntu proot setup, and Python 3.13 via deadsnakes PPA.

---

## 🛠️ Manual Installation (Step-by-Step)

Prefer to do it yourself? Here's the step-by-step:

```bash
# 0. Install git
pkg install git
```

```bash
# 1. Clone this repository
git clone https://github.com/learn6096-ui/Hermes-Agent-On-Android.git
cd Hermes-Agent-On-Android

# 2. Make the script executable
chmod +x agent_install.sh

# 3. Run the installer
./agent_install.sh
```

---

## 🤖 Start the Agent

Run these commands one by one after installing:

```bash
# Enter the Ubuntu proot environment
proot-distro login ubuntu
```

```bash
# Navigate to hermes and activate the virtual environment
cd hermes-agent
source venv/bin/activate
```

### First-time setup:
```bash
hermes setup
```

### Start using it:
```bash
hermes
```

### Start the gateway:
```bash
hermes gateway
```

---

## 📜 Available Install Scripts

| Script | Approach | Best For |
|--------|----------|----------|
| `nous_hermes_agent_install.sh` | proot-Ubuntu | ⭐ **Recommended** — Most robust, full error handling |
| `nous_agent.sh` | proot-Ubuntu | One-liner compatible, good error handling |
| `agent_install.sh` | proot-Ubuntu | Simple manual installation |
| `proot_install.sh` | proot-Ubuntu | Basic proot installer |
| `install.sh` | Direct Termux | Native Termux install (no Ubuntu) |
| `hermes_install.sh` | Direct Termux | One-liner native Termux install |

---

## 🐍 Python 3.13 Compatibility

All scripts are fully compatible with **Python 3.13.x**:

- **Direct Termux scripts** (`install.sh`, `hermes_install.sh`): Use Termux's native Python 3.13 with a `psutil` sysconfig patch to fix the `-fno-openmp-implicit-rpath` compiler flag issue
- **proot-Ubuntu scripts**: Use the [deadsnakes PPA](https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa) to install Python 3.13 inside Ubuntu, with `update-alternatives` to set it as default

> [!IMPORTANT]
> The `psutil` sysconfig patch is critical for Direct Termux installs. Without it, `psutil` (a dependency of Hermes Agent) fails to compile on Python 3.13 due to an unsupported Clang compiler flag.

---

## ⚙️ System Requirements

| Requirement | Minimum | Recommended |
|:------------|:-------:|-------------:|
| **Android Version** | 11  |  13, 14 or 15 |
| **Storage Space** | 3GB | 5GB+ |
| **RAM** | 2GB | 4GB+ |
| **Internet** | Required | Fast connection |
| **Termux** | Latest | Latest from F-Droid |
| **Python** | 3.13 | 3.13.x |

---

## 🌍 Why Run Hermes on Android?

| Benefit | Description |
|:--------|:-----------:|
| **📱 Portable AI** | Your assistant goes everywhere |
| **🔒 Privacy** | Runs locally on your device |
| **💰 Cost-effective** | No server hosting fees |
| **⚡ Low latency** | Direct execution |
| **🔄 Always available** | Works offline (with local models) |

---

## 🎛️ AI Model Freedom

Compatible with 200+ AI models including:

• OpenAI (GPT-4, GPT-3.5)
• Anthropic (Claude)
• Google (Gemini)
• DeepSeek
• Alibaba (Qwen)
• Zhipu (GLM)
• Local models via Ollama

---

## 🦙 Running Local Models with [Ollama](https://ollama.com)

### 📋 Installation

#### Install Ollama on Termux:
```bash
pkg install ollama
ollama serve
```

#### Pull & Run Models:
```bash
ollama run gemma4:31b-cloud
```

---

## 🔧 Troubleshooting

<details>
<summary><strong>psutil build fails on Python 3.13</strong></summary>

This is fixed in the install scripts. If you're doing a manual install, run:
```bash
_file="$(find $PREFIX/lib/python3.* -name "_sysconfigdata*.py" 2>/dev/null | head -1)"
cp "$_file" "$_file.backup"
sed -i 's|-fno-openmp-implicit-rpath||g' "$_file"
rm -rf $PREFIX/lib/python3.*/__pycache__
```
</details>

<details>
<summary><strong>pip install fails with "externally-managed-environment"</strong></summary>

Always use a virtual environment:
```bash
python3.13 -m venv venv
source venv/bin/activate
pip install -e .
```
</details>

<details>
<summary><strong>Ubuntu proot installation hangs</strong></summary>

Make sure `DEBIAN_FRONTEND=noninteractive` is set before running apt commands. All scripts now include this fix.
</details>

---

## 🙏 Acknowledgments

• [Nous Research](https://github.com/NousResearch) - For creating the amazing Hermes Agent
• [Termux Team](https://termux.com/) - For making Android development possible
• Open Source Community - For the countless tools and libraries
• You - For using and supporting this project! ❤️


<div align="center">

## **⭐ If this helped you, give it a star! ⭐**

</div>
