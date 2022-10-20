// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

// solhint-disable func-name-mixedcase

import { AppStorage } from "src/diamonds/nayms/AppStorage.sol";
import { Nayms } from "src/diamonds/nayms/Nayms.sol";
import { INayms } from "src/diamonds/nayms/INayms.sol";
import { InitDiamond } from "src/diamonds/nayms/InitDiamond.sol";

import { LibGeneratedNaymsFacetHelpers } from "script/utils/LibGeneratedNaymsFacetHelpers.sol";

contract FuzzyDiamond is Nayms(msg.sender) {
    address private owner;

    constructor() {
        address[] memory naymsFacetAddresses = LibGeneratedNaymsFacetHelpers.deployNaymsFacets();
        INayms.FacetCut[] memory cut = LibGeneratedNaymsFacetHelpers.createNaymsDiamondFunctionsCut(naymsFacetAddresses);

        InitDiamond initDiamond = new InitDiamond();
        INayms self = INayms(address(this));
        self.diamondCut(cut, address(initDiamond), abi.encodeCall(initDiamond.initialize, ()));
    }

    function echidna_only_owner() public view returns (bool) {
        return owner == msg.sender;
    }
}
