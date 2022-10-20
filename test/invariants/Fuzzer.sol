// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

// solhint-disable func-name-mixedcase

import { LibConstants } from "src/diamonds/nayms/libs/LibConstants.sol";
import { LibHelpers } from "src/diamonds/nayms/libs/LibHelpers.sol";
import { AdminFacet } from "src/diamonds/nayms/facets/AdminFacet.sol";

contract Fuzzer is AdminFacet {
    constructor() {}

    function echidna_system() public view returns (bool) {
        return LibHelpers._stringToBytes32(LibConstants.SYSTEM_IDENTIFIER) == this.getSystemId();
    }
}
