# Open890 Marker Buttons Build

This repository contains a custom workflow to build **Open890 v1.2.0** with added
**Red / Green / Blue marker toggle buttons**.

## How to Build

1. Go to the **Actions** tab of this repository.
2. Select **Build Open890 with Marker Buttons** from the left sidebar.
3. Click **Run workflow** → **Run workflow** again to start the build.
4. Wait ~3–4 minutes for the build to complete.
5. Scroll to the bottom of the workflow run page → expand **Artifacts** → download
   **open890-marker-buttons.zip**.

## What’s Inside

- Fully compiled Phoenix production release of Open890 v1.2.0.
- Adds three buttons in the UI:
  - **Red**, **Green**, **Blue** with hover tooltips.
- Toggles markers using ±200 Hz logic:
  - If a marker of the selected color is present near the current frequency,
    it is cleared.
  - Otherwise, a new marker is created exactly on-frequency.

## Usage

Unzip the artifact and run:

```bash
bin/open890 start
```

or on Windows:

```cmd
bin\open890.bat
```

Then open the web UI (http://localhost:4000 by default) and you should see the
new **Markers:** section with buttons.

