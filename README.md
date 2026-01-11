# RV32I 32-bit 5-Stage Pipelined RISC-V CPU (SystemVerilog)

This repository contains four implementations of a 32-bit **RISC-V pipelined CPU**, each exploring different hazard handling and branch prediction techniques.  
All models share the same verification environment (`01_bench`), test programs (`02_test`), and simulation setup (`03_sim`).

---

## 🧩 Pipeline Models Overview

| Model | Forwarding | Hazard Handling | Branch Predictor |
|--------|-------------|------------------|------------------|
| **Model 1:** `pl_test-model-1_non-forwarding` | ❌ | Stall-based RAW hazard detection | None |
| **Model 2:** `pl_test-model-2_forwarding` | ✅ | Forwarding + load-use stall | None |
| **Model 3:** `pl_test-model-3_two-bit-dynamic` | ✅ | Forwarding + load-use stall | 2-bit BHT (1024 entries) |
| **Model 4:** `pl_test-model-4_gshare` | ✅ | Forwarding + load-use stall | Gshare (10-bit GHR ⊕ PC index) |

---

## ⚙️ Pipeline Architecture
- **5 pipeline stages:** IF → ID → EX → MEM → WB  
- **Pipeline registers:** IF/ID, ID/EX, EX/MEM, MEM/WB  
- **Hazard Unit:** detects load-use hazards, issues stall  
- **Forwarding Unit:** forwards EX/MEM and MEM/WB results to minimize stalls  
- **Branch Prediction Units:**
  - *Model 3:* per-PC 2-bit saturating counter  
  - *Model 4:* Gshare predictor with 10-bit global history  

---

## 💾 Supported ISA & Memory Map

### Instruction Set (RV32I)
- **R-type:** ADD, SUB, SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA  
- **I-type:** ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI  
- **Load/Store:** LB, LH, LW, LBU, LHU, SB, SH, SW  
- **Branch:** BEQ, BNE, BLT, BGE, BLTU, BGEU  
- **Jump:** JAL, JALR  
- **U-type:** LUI, AUIPC  

### Memory-Mapped I/O
| Address | Function |
|----------|-----------|
| `0x0000_0000` – `0x0000_FFFF` | Instruction/Data Memory |
| `0x1000_0000` | LEDR |
| `0x1000_1000` | LEDG |
| `0x1000_2000` | HEX3–0 |
| `0x1000_3000` | HEX7–4 |
| `0x1000_4000` | LCD |
| `0x1001_0000` | Switch Input |

---

## 🧠 Verification Environment

- **Location:** `01_bench/`  
- **Components:** driver, scoreboard, top-level testbench (`tbench.sv`)  
- **Scoreboard Output:**
  - Total cycles executed
  - Total executed instructions
  - Branch instructions + mispredictions
  - **IPC (Instructions per Cycle)**
  - **Branch misprediction rate**

---

## 🧪 Simulation Results

| Model | Total Cycles | Total Instr. | IPC | Branch Mispred. | Mispredict Rate |
|--------|--------------|---------------|------|------------------|------------------|
| **Non-forwarding** | 12,893 | 4,826 | **0.37** | 709 | **44.26%** |
| **Forwarding** | 7,829 | 4,826 | **0.62** | 1,449 | **90.45%** |
| **2-bit Dynamic** | 5,743 | 4,929 | **0.86** | 709 | **44.26%** |
| **Gshare** | 5,743 | 4,929 | **0.86** | 709 | **44.26%** |

✅ *All ISA tests passed (`PASS` for all instructions)*  
📈 IPC improves from 0.37 (stall-only) → 0.86 (predictor models).  
Forwarding and branch prediction both reduce stalls and improve throughput.

---

## 🧰 Simulation Workflow (Cadence Xcelium)

Example: Run model 4 (Gshare)
```bash
cd pl_test-model-4_gshare/03_sim
make create_filelist
make sim
