// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

// solhint-disable

import { LibConstants } from "src/diamonds/nayms/libs/LibConstants.sol";
import { LibHelpers } from "src/diamonds/nayms/libs/LibHelpers.sol";
import { Nayms } from "src/diamonds/nayms/Nayms.sol";
import { INayms } from "src/diamonds/nayms/INayms.sol";
import { InitDiamond } from "src/diamonds/nayms/InitDiamond.sol";
import { LibGeneratedNaymsFacetHelpers } from "script/utils/LibGeneratedNaymsFacetHelpers.sol";

contract Fuzzer is Nayms(msg.sender) {
    constructor() payable {
        address[] memory naymsFacetAddresses = LibGeneratedNaymsFacetHelpers.deployNaymsFacets();
        INayms.FacetCut[] memory cut = LibGeneratedNaymsFacetHelpers.createNaymsDiamondFunctionsCut(naymsFacetAddresses);

        INayms nayms = INayms(address(this));
        InitDiamond initDiamond = new InitDiamond();
        nayms.diamondCut(cut, address(initDiamond), abi.encodeCall(initDiamond.initialize, ()));
    }

    function echidna_system() public view returns (bool) {
        INayms nayms = INayms(address(this));
        return nayms.owner() != address(0x00000000000000000000000000000000DeaDBeef);
        // return LibHelpers._stringToBytes32(LibConstants.SYSTEM_IDENTIFIER) == nayms.getSystemId();
    }
}
