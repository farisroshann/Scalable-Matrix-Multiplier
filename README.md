# Systolic 4x4 Matrix Multiplier

4×4 FP16 → FP32 Output-Stationary Systolic ArrayA hardware implementation and verification suite for a 4×4 Output-Stationary Systolic Array designed in Verilog HDL. The array performs mixed-precision matrix multiplication ($C = A \times B$), accepting IEEE 754 half-precision (FP16) inputs and accumulating products into IEEE 754 single-precision (FP32) outputs.

The design implements an output-stationary systolic array (`systolic_4`) composed of 16 interconnected Processing Elements (PEs) arranged in a 4×4 grid:

* **Dataflow:** Matrix **A** elements stream horizontally from left to right across rows (`a_in`), while Matrix **B** elements stream vertically from top to bottom down columns (`b_col_in`).
* **Processing Elements (PEs):** Each PE performs a 16-bit multiplication and accumulates the partial product into a local 32-bit register every clock cycle.
* **Parallel Output:** Once computation completes, all 16 accumulated 32-bit results are exposed simultaneously via the flattened `acc_out_grid` bus (`[511:0]`).


<img width="971" height="542" alt="image" src="https://github.com/user-attachments/assets/07bded83-b3b0-401d-98df-cf322838e8d9" />

<img width="1157" height="308" alt="image" src="https://github.com/user-attachments/assets/fa8039e9-2bab-4089-8d7d-0ca90c543fa0" />

<img width="1157" height="308" alt="image" src="https://github.com/user-attachments/assets/2109d44e-8bcc-475f-86ed-ade37e37ecaa" />


Scalable-Matrix-Multiplier/
├── Scalable Matrix/          # Xilinx Vivado project & RTL source files
│   └── Scalable Matrix.srcs/
│       ├── sources_1/new/    # Core RTL modules (systolic_4.v, pe_16.v  module)
│       └── sim_1/new/        # Testbenches (tb_systolic_input.v)
├── run_data/                 # Input test vectors (matrix_a.txt, matrix_b.txt) & simulation outputs (Import these as simulation source)
└── README.md  

Output.txt is generates inside Scalable Matrix.sim\sim_1\behav\xsim\output.txt





