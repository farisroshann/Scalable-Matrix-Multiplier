# Systolic 4×4 Matrix Multiplier

**4×4 FP16 → FP32 Output-Stationary Systolic Array**

A hardware implementation and verification suite for a 4×4 Output-Stationary Systolic Array designed in Verilog HDL. The array performs mixed-precision matrix multiplication (\(C = A \times B\)), accepting IEEE 754 half-precision (FP16) inputs and accumulating products into IEEE 754 single-precision (FP32) outputs.

---

## Architecture & Dataflow

The design implements an output-stationary systolic array (`systolic_4`) composed of 16 interconnected Processing Elements (PEs) arranged in a 4×4 grid:

<p align="center">
  <img width="800" alt="4x4 Systolic Array Architecture Diagram" src="https://github.com/user-attachments/assets/07bded83-b3b0-401d-98df-cf322838e8d9" />
</p>

* **Dataflow:** Matrix **A** elements stream horizontally from left to right across rows (`a_in`), while Matrix **B** elements stream vertically from top to bottom down columns (`b_col_in`).
* **Processing Elements (PEs):** Each PE performs a 16-bit floating-point multiplication and accumulates the partial product into a local 32-bit register every clock cycle.
* **Parallel Output:** Once computation completes, all 16 accumulated 32-bit results are exposed simultaneously via the flattened `acc_out_grid` bus (`[511:0]`).

---

## Verification Results

The testbench loads 4×4 FP16 matrices from text files and verifies the resulting FP32 matrix products against expected values:

<p align="center">
  <img width="950" alt="Matrix Multiplication Verification Results" src="https://github.com/user-attachments/assets/fa8039e9-2bab-4089-8d7d-0ca90c543fa0" />
</p>

---

## Repository Structure

```text
Scalable-Matrix-Multiplier/
├── Scalable Matrix/              # Xilinx Vivado project & RTL source files
│   └── Scalable Matrix.srcs/
│       ├── sources_1/new/        # Core RTL modules (systolic_4.v, pe_16.v)
│       └── sim_1/new/            # Testbenches (tb_systolic_input.v)
├── run_data/                     # Input test vectors (matrix_a.txt, matrix_b.txt) & reference outputs
└── README.md
```

---

## Simulation & Usage

1. Open the project in **Xilinx Vivado**.
2. Import the test vector files (`matrix_a.txt` and `matrix_b.txt`) from the `run_data/` directory as simulation sources.
3. Run behavioral simulation using `tb_systolic_input.v`.
4. After simulation finishes, `output.txt` is automatically generated at:
   ```text
   Scalable Matrix/Scalable Matrix.sim/sim_1/behav/xsim/output.txt
   ```
