# Pairing Verifier

A Vyper smart contract for verifying a simplified bilinear pairing equation on the BN254 elliptic curve using Ethereum precompiles. This implements a basic zk-SNARK-like verification setup for educational purposes, based on the equation:


$`0 = -A_1 B_2 + \alpha_1 \beta_2 + X_1 \gamma_2 + C_1 \delta_2`$

where $`X_1 = x_1 G_1 + x_2 G_1 + x_3 G_1`$, and points are in groups $`\mathbb{G}_1`$ or $`\mathbb{G}_2`$.

The contract computes $`X_1`$ on-chain, negates the pairing term for $`-A_1 B_2`$, and checks if the product of pairings equals 1 in the target group $`\mathbb{G}_T`$.

## Features

- Uses Ethereum precompiles for elliptic curve addition (0x06), scalar multiplication (0x07), and multi-pairing (0x08).
- Hardcoded verification key points ($`\alpha_1, \beta_2, \gamma_2, \delta_2`$) for efficiency.
- Dynamic inputs: Proof elements $`A_1`$ (G1), $`B_2`$ (G2), $`C_1`$ (G1), and public scalars $`x_1, x_2, x_3`$.
- Balanced with nontrivial scalars (e.g., $`x_1=2, x_2=3, x_3=-4 \mod r`$) for testing.

## Mathematical Background

This project demonstrates key mathematical concepts from  cryptography, particularly in zero-knowledge proofs (ZKPs). The core relies on bilinear pairings over elliptic curves, which enable efficient verification of computations without revealing private data. Below, we break down the math, tie it to the project's equation, and map it to a real Groth16 zk-SNARK example.

### Bilinear Pairings Basics

Bilinear pairings are functions $`e: \mathbb{G}_1 \times \mathbb{G}_2 \to \mathbb{G}_T`$ on elliptic curve groups with properties like bilinearity ($`e(aP, bQ) = e(P, Q)^{ab}`$) and non-degeneracy. On BN254 (used here), $`\mathbb{G}_1`$ and $`\mathbb{G}_2`$ are additive groups over finite fields, and $`\mathbb{G}_T`$ is multiplicative.
The equation "0 = -A1 B2 + α1 β2 + X1 γ2 + C1 δ2" represents a scalar equation in the discrete log of $`\mathbb{G}_T`$: the product $`e(-A_1, B_2) \cdot e(\alpha_1, \beta_2) \cdot e(X_1, \gamma_2) \cdot e(C_1, \delta_2) = 1`$ in $`\mathbb{G}_T`$. This checks if the exponents sum to zero modulo the curve order.

- Why pairings? They allow "multiplication" of group elements from different groups, enabling succinct proofs for arithmetic circuits.

### Why Hardcoded vs. Dynamic Values?

- Hardcoded points ($`\alpha_1, \beta_2, \gamma_2, \delta_2`$): These are fixed for a specific circuit (computation being proved). In ZK, they're part of the verification key (VK) from a trusted setup. Precomputing offchain (e.g., via py_ecc) and hardcoding saves gas; on-chain computation would be expensive.
- Dynamic arguments (A1, B2, C1, x1, x2, x3): These vary per proof/call. A1, B2, C1 are prover-supplied proof elements. x1, x2, x3 are "public inputs" (visible data like transaction IDs).

This separation mirrors real ZK verifiers: reusable for the same circuit, customizable per instance.

### Tying to Groth16 zk-SNARKs

Groth16 is a popular zk-SNARK for proving knowledge of witnesses satisfying arithmetic circuits (e.g., in Tornado Cash for privacy). The verifier equation is:

$`e(A, B) = e(\alpha, \beta) \cdot e(D, \gamma) \cdot e(C, \delta)`$

where:
- Proof elements (dynamic): A (G1, like A1), B (G2, like B2), C (G1, like C1). Provided by the prover.
- Verification key (VK, hardcoded/fixed): α (G1, like α1), β (G2, like β2), γ (G2, like γ2), δ (G2, like δ2), plus input coefficients (IC) for public inputs.
- Public inputs term (computed on-chain): D = sum (pub_i * IC_i) in G1 (like X1, but with distinct IC points instead of all G1).
- Public inputs: The pub_i (like x1, x2, x3) are scalars representing visible data.

Our equation matches with a sign flip: the "-A1 B2" term implements e(-A, B) or the inverse to make the product ==1. In practice, Groth16 uses a trusted setup to generate VK, ensuring security based on hardness assumptions (e.g., discrete log in pairings).

This project simplifies Groth16 by:
- Using the same base for public inputs (no full IC array).
- Focusing on pairing mechanics without a full circuit.

## Setup and Usage

1. Generate Constants and Inputs (offchain)
Use `py_ecc` to compute elliptic curve points from chosen scalars. Example script (`constants.py`):
```python
from py_ecc.bn128 import G1, G2, multiply

# Scalars for balance: -1*1 +1*1 +1*1 +1*(-1) = 0
_A1 = 1
_B2 = 1
_a1 = 1
_b2 = 1
_x1 = 2
_x2 = 3
_x3 = 4  # Input as r - 4 in contract
_g2 = 1
_C1 = 1
_D2 = 1 # -1

# Curve order r
r = 21888242871839275222246405745257275088548364400416034343698204186575808495617

A1 = multiply(G1, _A1)
B2 = multiply(G2, _B2)
a1 = multiply(G1, _a1)
b2 = multiply(G2, _b2)
g2 = multiply(G2, _g2)
C1 = multiply(G1, _C1)
D2 = neg(multiply(G2, _D2))

# Print for hardcoding (G2: im first, re second for precompile)
print("ALPHA1:", a1)
print("BETA2:", ((b2[0].imag, b2[0].real), (b2[1].imag, b2[1].real)))
print("GAMMA2:", ((g2[0].imag, g2[0].real), (g2[1].imag, g2[1].real)))
print("DELTA2:", ((D2[0].imag, D2[0].real), (D2[1].imag, D2[1].real)))

print("\nTest Inputs:")
print("A1:", A1)
print("B2:", ((B2[0].imag, B2[0].real), (B2[1].imag, B2[1].real)))
print("C1:", C1)
print("x1:", _x1)
print("x2:", _x2)
print("x3:", r - _x3)  # Positive mod r
```

2. Contract Code

The contract is in `pairing_verifier.vy`. Key functions:
- `verify(A1: ECPoint, B2: G2Point, C1: ECPoint, x1: uint256, x2: uint256, x3: uint256) -> bool`: Computes X1, prepares pairing inputs, and returns True if verified.

3. Testing

```
mox test
```

## Notes
- G2 Coordinate Order: Always input as [imag, real] for x and y in precompiles. Opposite of `py_ecc` output.
- Gas Efficiency: Suitable for on-chain ZK verification; expand for full Groth16 by adding more VK points.
- Limitations: Assumes valid points (no on-curve checks); add if needed for production.
- The ate pairing check on the elliptic curve alt_bn128 precompile was introduced in [EIP-197](https://eips.ethereum.org/EIPS/eip-197)
