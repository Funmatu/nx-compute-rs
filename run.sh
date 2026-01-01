#!/bin/bash
set -e

# プロジェクト設定
PROJECT_NAME="nx_compute_rs" # Rustのクレート名はスネークケース
REPO_NAME="nx-compute-rs"    # リポジトリ名はケバブケース

echo "🚀 Initializing R&D Dual-Runtime Project: $REPO_NAME..."

# ディレクトリ作成
mkdir -p $REPO_NAME
cd $REPO_NAME
mkdir -p .github/workflows
mkdir -p src
mkdir -p www

# ==========================================
# 1. Cargo.toml (Rust設定)
# ==========================================
cat << EOF > Cargo.toml
[package]
name = "$PROJECT_NAME"
version = "0.1.0"
edition = "2026"
authors = ["R&D Researcher funmatu@gmail.com"]
description = "A dual-runtime computation core for WebAssembly and Python, powered by Rust."

[lib]
name = "$PROJECT_NAME"
crate-type = ["cdylib"]

[features]
default = ["wasm"]
wasm = ["dep:wasm-bindgen"]
python = ["dep:pyo3"]

[dependencies]
# Common dependencies (Math, etc.)
serde = { version = "1.0", features = ["derive"] }

# Feature: WebAssembly
wasm-bindgen = { version = "0.2", optional = true }

# Feature: Python
pyo3 = { version = "0.20", features = ["extension-module"], optional = true }

[profile.release]
lto = true
opt-level = 3
codegen-units = 1
EOF

# ==========================================
# 2. pyproject.toml (Python/Maturin設定)
# ==========================================
cat << EOF > pyproject.toml
[build-system]
requires = ["maturin>=1.0,<2.0"]
build-backend = "maturin"

[project]
name = "$PROJECT_NAME"
requires-python = ">=3.8"
classifiers = [
    "Programming Language :: Rust",
    "Programming Language :: Python :: Implementation :: CPython",
    "Programming Language :: Python :: Implementation :: PyPy",
]
dynamic = ["version"]
EOF

# ==========================================
# 3. Rust Source Code (src/lib.rs)
# ==========================================
cat << EOF > src/lib.rs
use std::f64::consts::PI;

/// Core Algorithm: Heavy computation simulation.
/// In a real scenario, this would be a SLAM backend, Optimization solver, or Physics engine.
fn core_algorithm(iterations: u64, param: f64) -> f64 {
    let mut sum = 0.0;
    for i in 0..iterations {
        let x = (i as f64) * PI / 180.0;
        sum += (x * param).sin() * (x * param).cos();
    }
    sum
}

// -----------------------------------------------------------------------------
// Module: Python Interface (PyO3)
// -----------------------------------------------------------------------------
#[cfg(feature = "python")]
use pyo3::prelude::*;

#[cfg(feature = "python")]
#[pyfunction]
fn compute_metrics(iterations: u64, param: f64) -> PyResult<f64> {
    Ok(core_algorithm(iterations, param))
}

#[cfg(feature = "python")]
#[pymodule]
fn $PROJECT_NAME(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(compute_metrics, m)?)?;
    Ok(())
}

// -----------------------------------------------------------------------------
// Module: WebAssembly Interface (wasm-bindgen)
// -----------------------------------------------------------------------------
#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub fn compute_metrics_js(iterations: u64, param: f64) -> f64 {
    core_algorithm(iterations, param)
}
EOF

# ==========================================
# 4. Web Frontend (www/)
# ==========================================
cat << EOF > www/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$REPO_NAME Demo</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
        h1 { border-bottom: 2px solid #eee; padding-bottom: 0.5rem; }
        .card { border: 1px solid #ddd; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        button { background-color: #0070f3; color: white; border: none; padding: 0.8rem 1.5rem; border-radius: 5px; cursor: pointer; font-size: 1rem; }
        button:hover { background-color: #005bb5; }
        button:disabled { background-color: #ccc; cursor: not-allowed; }
        #output { margin-top: 1rem; padding: 1rem; background: #f5f5f5; border-radius: 5px; font-family: monospace; }
    </style>
</head>
<body>
    <h1>$REPO_NAME</h1>
    <p>R&D Dual-Runtime Architecture Proof of Concept.</p>
    
    <div class="card">
        <h3>WebAssembly Computation</h3>
        <p>Run the rigorous Rust backend directly in your browser.</p>
        <button id="run-btn" disabled>Loading WASM...</button>
        <div id="output">Waiting for input...</div>
    </div>

    <script type="module" src="./index.js"></script>
</body>
</html>
EOF

cat << EOF > www/index.js
import init, { compute_metrics_js } from './pkg/$PROJECT_NAME.js';

async function run() {
    await init(); // Initialize WASM
    
    const btn = document.getElementById('run-btn');
    const output = document.getElementById('output');
    
    btn.innerText = "Run Core Algorithm (10M iters)";
    btn.disabled = false;

    btn.addEventListener('click', () => {
        output.innerText = "Computing...";
        
        // Use setTimeout to allow UI to update before blocking main thread
        setTimeout(() => {
            const start = performance.now();
            
            // Call Rust function
            const result = compute_metrics_js(10_000_000n, 1.5);
            
            const end = performance.now();
            output.innerText = \`Result: \${result.toFixed(6)}\nTime: \${(end - start).toFixed(2)} ms\`;
        }, 10);
    });
}

run();
EOF

# ==========================================
# 5. GitHub Actions (CI/CD)
# ==========================================
cat << EOF > .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build-wasm:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          profile: minimal
          override: true

      - name: Install wasm-pack
        run: curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

      - name: Build WASM
        run: wasm-pack build --target web --out-dir www/pkg --no-default-features --features wasm

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: \${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./www

  test-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
          
      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Install Maturin
        run: pip install maturin
        
      - name: Build and Test Python Module
        run: |
          maturin develop --features python
          python -c "import $PROJECT_NAME; print(f'Test Result: {$PROJECT_NAME.compute_metrics(1000, 1.0)}')"
EOF

# ==========================================
# 6. README.md (Comprehensive Documentation)
# ==========================================
# Note: The README content is defined in the response below, but we write it here too.
cat << EOF > README.md
# Nexus Compute RS: Dual-Runtime R&D Architecture

![Build Status](https://github.com/USERNAME/$REPO_NAME/actions/workflows/deploy.yml/badge.svg)
![Rust](https://img.shields.io/badge/Language-Rust-orange.svg)
![Platform](https://img.shields.io/badge/Platform-WASM%20%7C%20Python-blue.svg)

**Nexus Compute RS** is a rigorous proof-of-concept template designed for R&D in Physical AI and Robotics. It implements a "Write Once, Run Everywhere" strategy for high-performance algorithms, bridging the gap between web-based visualization/sharing and Python-based rigorous analysis/backend processing.

## 1. Architectural Philosophy

In modern R&D, we often face a dilemma:
* **Python** is required for data analysis, ML integration (PyTorch), and ROS2 interfacing.
* **Web (JavaScript)** is required for easy sharing, visualization, and zero-setup demos.
* **Performance** is critical for SLAM, Optimization, and Simulation.

This project solves this by implementing the core logic in **Rust**, which is then compiled into two distinct targets via Feature Flags:

\`\`\`mermaid
graph TD
    subgraph "Core Logic (Rust)"
        Alg[Algorithm / Physics / Math]
    end

    subgraph "Target: Web (WASM)"
        WB[wasm-bindgen]
        JS[JavaScript / Browser]
        Alg --> WB --> JS
    end

    subgraph "Target: Python (Native)"
        PyO3[PyO3 Bindings]
        Py[Python Environment]
        Alg --> PyO3 --> Py
    end
\`\`\`

## 2. Project Structure

\`\`\`text
$REPO_NAME/
├── .github/workflows/   # CI/CD for automatic WASM deployment & Python testing
├── src/
│   └── lib.rs           # The SINGLE source of truth. Contains core logic + bindings.
├── www/                 # The Web Frontend (HTML/JS)
│   ├── index.html
│   ├── index.js
│   └── pkg/             # Generated WASM artifacts (by CI)
├── Cargo.toml           # Rust configuration (defines 'wasm' and 'python' features)
├── pyproject.toml       # Python build configuration (Maturin)
└── README.md            # This document
\`\`\`

## 3. Usage Guide

### A. As a Python Library (For Analysis/Backend)

You can use the Rust core as a native Python extension. This provides near-C++ performance within your Python scripts.

**Prerequisites:**
* Rust toolchain (\`rustup\`)
* Python 3.8+
* \`pip install maturin\`

**Setup & Run:**
\`\`\`bash
# 1. Build and install into current venv
maturin develop --features python

# 2. Run in Python
python -c "import $PROJECT_NAME; print($PROJECT_NAME.compute_metrics(1000000, 1.5))"
\`\`\`

### B. As a Web Application (For Demo/Sharing)

You can run the same logic in the browser via WebAssembly.

**Prerequisites:**
* \`wasm-pack\` (\`curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh\`)

**Setup & Run:**
\`\`\`bash
# 1. Build WASM blob
wasm-pack build --target web --out-dir www/pkg --no-default-features --features wasm

# 2. Serve locally (using Python's http server for simplicity)
cd www
python3 -m http.server 8000
# Open http://localhost:8000
\`\`\`

## 4. Technical Details

### Feature Flags Strategy
We use \`Cargo.toml\` features to minimize binary size and dependencies.
* **\`features = ["wasm"]\`**: Includes \`wasm-bindgen\`. Generates \`.wasm\` binary. Panics happen in JS console.
* **\`features = ["python"]\`**: Includes \`pyo3\`. Generates \`.so/.pyd\` shared library. Python exception handling enabled.

### Performance Considerations
* **Zero-Cost Abstraction:** Rust's iterators and logic compile down to optimized machine code (simd instructions where applicable) for Python, and optimized bytecode for WASM.
* **Memory Safety:** No manual memory management (malloc/free) required, preventing segfaults in Python extensions.
* **GIL (Global Interpreter Lock):** The Rust code runs outside Python's GIL. For multi-threaded logic, Rust can utilize all CPU cores while Python is blocked, offering true parallelism.

## 5. Deployment

This repository uses **GitHub Actions** to automatically deploy the Web version.
1.  Push to \`main\`.
2.  Action triggers: Compiles Rust to WASM.
3.  Deploys \`www/\` folder to **GitHub Pages**.

## 6. Future Roadmap

* **GPU Acceleration:** Integrate \`wgpu\` for portable GPU compute shaders (WebGPU + Vulkan/Metal).
* **Serialization:** Add \`serde\` support to pass complex JSON/Structs between JS/Python and Rust.
* **Sim2Real:** Port the Python bindings directly to a ROS2 node.

---
*Author: Funmatu*
EOF

# Git初期化 (オプション)
# git init
git add .
echo "✅ Project '$REPO_NAME' generated successfully!"
echo "   -> Next step: 'cd $REPO_NAME' and follow the README."