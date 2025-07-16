# pragma version ^0.4.0
"""
@title BN-254 Pairing Verifier
@custom:contract-name pairing_verifier
@license GNU Affero General Public License v3.0 only
@author 0xpantera
@notice Verifies 0 = -A1*B2 + alpha1*beta2 + X1*gamma2 + C1*delta2
        where X1 = x1*G1 + x2*G1 + x3*G1
        using Ethereum precompiles.
"""

# BN-254 primes
# @dev Base Field modulus p
P: constant(uint256) = (
    21888242871839275222246405745257275088696311157297823662689037894645226208583
)
# @dev Scalar field modulus r
R: constant(uint256) = (
    21888242871839275222246405745257275088548364400416034343698204186575808495617
)

# Precompile addresses
_EC_ADD:  constant(address) = 0x0000000000000000000000000000000000000006
_EC_MUL:  constant(address) = 0x0000000000000000000000000000000000000007
_PAIRING: constant(address) = 0x0000000000000000000000000000000000000008

struct ECPoint:
    x: uint256
    y: uint256

struct G2Point:
    x: uint256[2]  # [x_im, x_re]
    y: uint256[2]  # [y_im, y_re]

G1_CONST: constant(ECPoint) = ECPoint(
    x=1,
    y=2
)

ALPHA1: constant(ECPoint) = ECPoint(
    x=1,
    y=2
)

BETA2: constant(G2Point) = G2Point(
    x=[
        11559732032986387107991004021392285783925812861821192530917403151452391805634, 
        10857046999023057135944570762232829481370756359578518086990519993285655852781
    ],
    y=[
        4082367875863433681332203403145435568316851327593401208105741076214120093531, 
        8495653923123431417604973247489272438418190587263600148770280649306958101930
    ]
)

GAMMA2: constant(G2Point) = G2Point(
    x=[
        11559732032986387107991004021392285783925812861821192530917403151452391805634, 
        10857046999023057135944570762232829481370756359578518086990519993285655852781
    ],
    y=[
        4082367875863433681332203403145435568316851327593401208105741076214120093531, 
        8495653923123431417604973247489272438418190587263600148770280649306958101930
    ]
)

DELTA2: constant(G2Point) = G2Point(
    x=[
        11559732032986387107991004021392285783925812861821192530917403151452391805634, 
        10857046999023057135944570762232829481370756359578518086990519993285655852781
    ],
    y=[
        17805874995975841540914202342111839520379459829704422454583296818431106115052, 
        13392588948715843804641432497768002650278120570034223513918757245338268106653
    ]
)

@deploy
@payable
def __init__():
    pass

@external
@view
def verify(
    A1: ECPoint,
    B2: G2Point,
    C1: ECPoint,
    x1: uint256,
    x2: uint256,
    x3: uint256
) -> bool:
    # Compute X1 = x1*G1 + x2*G1 + x3*G1
    temp1_x: uint256 = 0
    temp1_y: uint256 = 0
    (temp1_x, temp1_y) = self._ec_mul(G1_CONST.x, G1_CONST.y, x1)

    temp2_x: uint256 = 0
    temp2_y: uint256 = 0
    (temp2_x, temp2_y) = self._ec_mul(G1_CONST.x, G1_CONST.y, x2)

    temp3_x: uint256 = 0
    temp3_y: uint256 = 0
    (temp3_x, temp3_y) = self._ec_mul(G1_CONST.x, G1_CONST.y, x3)

    temp_x: uint256 = 0
    temp_y: uint256 = 0
    (temp_x, temp_y) = self._ec_add(temp1_x, temp1_y, temp2_x, temp2_y)

    X1_x: uint256 = 0
    X1_y: uint256 = 0
    (X1_x, X1_y) = self._ec_add(temp_x, temp_y, temp3_x, temp3_y)

    # negA1 for -A1 term
    negA1_y: uint256 = P - A1.y
    # No % P needed since A1.y < P assumed (valid point)

    # Prepare pairing input (4 pairs, 192 bytes each, total 768 bytes)
    payload: Bytes[768] = concat(
        convert(A1.x, bytes32), convert(negA1_y, bytes32),
        convert(B2.x[0], bytes32), convert(B2.x[1], bytes32),
        convert(B2.y[0], bytes32), convert(B2.y[1], bytes32),

        convert(ALPHA1.x, bytes32), convert(ALPHA1.y, bytes32),
        convert(BETA2.x[0], bytes32), convert(BETA2.x[1], bytes32),
        convert(BETA2.y[0], bytes32), convert(BETA2.y[1], bytes32),

        convert(X1_x, bytes32), convert(X1_y, bytes32),
        convert(GAMMA2.x[0], bytes32), convert(GAMMA2.x[1], bytes32),
        convert(GAMMA2.y[0], bytes32), convert(GAMMA2.y[1], bytes32),

        convert(C1.x, bytes32), convert(C1.y, bytes32),
        convert(DELTA2.x[0], bytes32), convert(DELTA2.x[1], bytes32),
        convert(DELTA2.y[0], bytes32), convert(DELTA2.y[1], bytes32)
    )

    out: Bytes[32] = raw_call(_PAIRING, payload, max_outsize=32, is_static_call=True)
    return convert(out, uint256) == 1

@internal
@view
def _ec_add(ax: uint256, ay: uint256, bx: uint256, by: uint256) -> (uint256, uint256):
    payload: Bytes[128] = concat(
        convert(ax, bytes32), convert(ay, bytes32),
        convert(bx, bytes32), convert(by, bytes32)
    )
    out: Bytes[64] = raw_call(_EC_ADD, payload, max_outsize=64, is_static_call=True)
    cx: uint256 = convert(slice(out, 0, 32), uint256)
    cy: uint256 = convert(slice(out, 32, 32), uint256)
    return cx, cy

@internal
@view
def _ec_mul(px: uint256, py: uint256, k: uint256) -> (uint256, uint256):
    payload: Bytes[96] = concat(
        convert(px, bytes32), convert(py, bytes32), convert(k, bytes32)
    )
    out: Bytes[64] = raw_call(_EC_MUL, payload, max_outsize=64, is_static_call=True)
    qx: uint256 = convert(slice(out, 0, 32), uint256)
    qy: uint256 = convert(slice(out, 32, 32), uint256)
    return qx, qy
