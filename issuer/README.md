# NFC Card Issuer

A web-based GUI for issuing DESFire cards without needing SSH access or a C
compiler on the issuing machine. It wraps the existing `pre_personalize`,
`personalize`, and `read_personalized` tools behind a simple browser interface.

## How it works

The `issuer` web server runs locally on the machine attached to the NFC reader.
When the operator clicks a button in the browser, the server spawns the
corresponding NFC tool as a subprocess, waits for it to complete, and shows the
output. The operator taps the card to the reader first, then clicks the button.

## Prerequisites

- An x86-64 machine running Ubuntu 24.04 (build machine)
- Podman or Docker
- Your site-specific key config files present in `c/`:
  - `c/dumb_node_config.c`
  - `c/smart_node_config.c`
  - `c/pre-personalize_config.c`

## Building

From the repo root:

```bash
./issuer/build.sh
```

This builds inside Ubuntu 24.04 containers and extracts four portable executables
into `issuer/`:

- `pre_personalize` — statically linked, sets up a blank card
- `personalize` — statically linked, writes a member ID to a pre-personalised card
- `read_personalized` — statically linked, reads and prints card info
- `issuer` — PyInstaller bundle containing the Python web server, all dependencies,
  and the browser UI; requires no Python installation on the target machine

## Deploying

Copy `pre_personalize`, `personalize`, `read_personalized`, `issuer`, `run.sh`,
`start.sh`, and `config.example.yml` to a directory on the target machine.

### 1. NFC reader permissions

By default Linux only allows root to open USB devices. Find your reader's USB IDs:

```bash
lsusb
# e.g. "ID 04cc:2533 ST-Ericsson NFC device (PN533)"
```

Create a udev rule and reload:

```bash
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="04cc", ATTRS{idProduct}=="2533", MODE="0664", GROUP="plugdev"' \
    | sudo tee /etc/udev/rules.d/99-nfc.rules

sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG plugdev $USER   # log out and back in after this
```

Replace `04cc` and `2533` with your reader's actual IDs.

### 2. Blacklist the kernel NFC driver

The Linux kernel's built-in PN533 driver claims the device before libnfc can open
it. Blacklist it:

```bash
echo -e "blacklist pn533\nblacklist pn533_usb" \
    | sudo tee /etc/modprobe.d/nfc-blacklist.conf

sudo modprobe -r pn533_usb pn533 nfc
```

### 3. Configure

```bash
cp config.example.yml config.yml
```

Edit `config.yml` — at minimum set `bin_dir` to the directory containing the NFC
tool binaries (`.` if everything is in the same directory).

### 4. Run

```bash
./start.sh
```

This starts the web server and opens the browser UI. Press Ctrl+C or close the
terminal to stop.

## Using the UI

Each operation follows the same pattern:

1. Tap the card to the NFC reader
2. Fill in any required fields (member ID for personalisation)
3. Click the button
4. Wait for the output — the tool polls for a card and runs automatically

### Operations

| Button | Card required | Description |
|---|---|---|
| Read Card | any issued card | Prints the card's UID, MID, and ACL |
| Pre-personalize | blank (factory) card | Sets up the nfclock application and keys |
| Personalize | pre-personalised card | Writes the member ID to issue the card |

### Card lifecycle

```
factory card  -->  pre-personalize  -->  personalize (enter MID)  -->  ready for doors
```

A card must be pre-personalised before it can be personalised. Running either
operation on the wrong card type will fail and show an error.
