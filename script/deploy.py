from src import Verifier
from moccasin.boa_tools import VyperContract

def deploy() -> VyperContract:
    verifier: VyperContract = Verifier.deploy()
    return verifier

def moccasin_main() -> VyperContract:
    return deploy()
