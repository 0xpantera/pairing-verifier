from py_ecc.bn128.bn128_curve import neg, multiply, G1, G2
from py_ecc.bn128.bn128_curve import curve_order

"""
0 = -A1*B2 + a1*b2 + X1*g2 + C1*d2
where
    X_1=x1*G1 + x2*G1 + x3*G1

inputs: A1, B2, C1, x1, x2, x3

Let G1 be a generator of {G}_1 and G2 a generator of {G}_2, 
with bilinear pairing e: {G}_1 x {G}_2 -> {G}_T. 
The equation represents the discrete log (with respect to a base in {G}_T) 
of the product of pairings equaling 1 in {G}_T:
- A1 = 1G1 (function parameter)
- B2 = 1G2 (function parameter)
- a1 = 1G1
- b2 = 1G2
- X1 = 1G1
- g2 = 1G2
- C1 = 1G1 (function parameter)
- D2 = -1G2
For X1 = x1*G1 + x2*G1 + x3*G1 = (x1 + x2 + x3)G1 = 1G1, set:
- x1 = 2 (function parameter)
- x2 = 3 (function parameter)
- x3 = -4 (function parameter)

Arguments (A1, B2, C1, x1, x2, x3): These represent the parts that change with each verification:
  - A1 (in G1), B2 (in G2), and C1 (in G1) are like "proof elements" — 
    they come from the prover and are unique to each proof. 
    The caller (e.g., a user submitting a transaction) provides them.
  - x1, x2, x3 (scalars as uint256) are like "public inputs" to the computation being verified. 
    In ZK, these could be visible values (e.i., tx amounts or IDs) that the proof references. 
    The contract computes X1 from them on-chain because they vary per call. Precomputing isn't possible.
Making these arguments allows the contract to be reusable: 
anyone can call the function with their own proof and inputs, 
and the contract verifies if they satisfy the equation.

Hardcoded points (alpha1, beta2, gamma2, delta2): These are like the verification key (VK) 
  — fixed values generated during a one-time setup phase for the specific computation or 
    circuit being verified. They're hardcoded as constants in the contract because:
    - They're the same for every verification of the same type of proof.
    - Computing them onchain would be gas expensive and unnecessary. 
      Do it once offchain and embed the results.
    - In practice, VKs come from a trusted setup (like in Groth16), 
      and hardcoding them ensures the contract is efficient and tamper-proof.

Why is X1 composed as X1 = x1*G1 + x2*G1 + x3*G1, and why all in G1?
This is a simplified demonstration of a "multi-scalar multiplication" (MSM) in G1, 
which is common in zk-SNARK verifiers:
  - G1 is the generator point for group {G}_1 (coordinates (1, 2) on BN254).
  - This is equivalent to X1 = (x1 + x2 + x3)G1 but then we wouldn't use precompiles?
  - Demonstrates how public inputs are folded into the pairing check via MSM.

Why all in G1 (no G2 here):
  - X1 must be in G1 because it's the left side of the pairing with gamma2 (in G2). 
    In ZK verifiers, public input terms are typically computed in G1 (as linear combinations of VK points in G1) and 
    paired with a fixed G2 point (like gamma2 here).
  
"""

# Proof
_A1 = 1
_B2 = 1
_C1 = 1

# Verifier Key
_a1 = 1
_b2 = 1
_g2 = 1
_D2 = 1 # -1

# Public inputs
_x1 = 2
_x2 = 3
_x3 = 4  # -4 Should it be `curve_order - 4` or `negate(G1, 4)`?

# Proof
A1 = multiply(G1, _A1)
B2 = multiply(G2, _B2)
C1 = multiply(G1, _C1)

# Verifier Key
a1 = multiply(G1, _a1)
b2 = multiply(G2, _b2)
g2 = multiply(G2, _g2)
D2 = neg(multiply(G2, _D2))

# computed in contract, but for reference
x1_G1 = multiply(G1, _x1)
x2_G1 = multiply(G1, _x2)
x3_G1 = neg(multiply(G1, _x3))



# Print coordinates for hardcoding and inputs
# G1 points: (x, y)
# G2 points: ((x_im, x_re), (y_im, y_re)) but for precompile: x=[x_im, x_re], y=[y_im, y_re]


print(f"ALPHA1 (a1): {a1}")
print(f"BETA2 (b2): {b2}")
print(f"GAMMA2 (g2): {g2}")
print(f"DELTA2 (D2): {D2}")

print("\nFunction Inputs:")
print(f"A1: {A1}")
print(f"B2: {B2}")
print(f"C1: {C1}")
print(f"x1: {_x1}")
print(f"x2: {_x2}")
print(f"x3 (as positive mod order): {curve_order - 4}")