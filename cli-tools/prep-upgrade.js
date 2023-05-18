const fs = require("fs");
const path = require("path");

// Define the FacetCutAction enum
// Define the FacetCutAction enum
const facetCutActionEnum = {
  0: "Add",
  1: "Replace",
  2: "Remove",
};

const filePath = process.argv[2]; // get the file path from CLI argument

fs.readFile(filePath, "utf8", (err, data) => {
  if (err) {
    console.error(`Error reading file from disk: ${err}`);
  } else {
    // parse the JSON file to a JavaScript object
    const json = JSON.parse(data);

    let valueStr = json.returns.cut.value.slice(1, -1); // Remove the outer brackets
    let tuplesStr = valueStr.split("), (");

    let facetCuts = tuplesStr.map((tupleStr) => {
      let tupleParts = tupleStr.slice(1, -1).split(", ");

      let facetAddress = tupleParts[0];
      let action = facetCutActionEnum[parseInt(tupleParts[1])];

      // Remove the brackets from the bytes4 array string, then split it by ', ' to get the individual elements
      let functionSelectorsStr = tupleParts[2].slice(1, -1);
      let functionSelectors = functionSelectorsStr.split(", ");

      return { facetAddress, action, functionSelectors };
    });
    // start constructing the Solidity script
    let script = `// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// ------------------------------------------------------------------------------------------------------------
///
/// NOTE: this file is auto-generated by ${path.basename(
      __filename
    )}, please DO NOT modify it directly. Unless you want to :)
///
/// ------------------------------------------------------------------------------------------------------------

import { IDiamondCut } from "src/diamonds/nayms/INayms.sol";
import "script/utils/DeploymentHelpers.sol";

contract S03UpgradeDiamond is DeploymentHelpers {
    using stdJson for string;

    function run(address _ownerAddress) external {
        INayms nayms = INayms(getDiamondAddressFromFile());

        if (_ownerAddress == address(0)) {
            _ownerAddress = nayms.owner();
        }

        string memory path = "${filePath}";
        string memory json = vm.readFile(path);
        bytes memory rawTxReturn = json.parseRaw(".returns.cut");
        TxReturn memory txReturn = abi.decode(rawTxReturn, (TxReturn));
        assertEq(txReturn.internalType, "struct IDiamondCut.FacetCut[]", "not the correct cut struct type");

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](${
          facetCuts.length
        });
`;

    // add the facetCuts data to the script
    facetCuts.forEach((facetCut, i) => {
      script += `
        bytes4[] memory f${i} = new bytes4[](${facetCut.functionSelectors.length});
    `;
      facetCut.functionSelectors.forEach((selector, j) => {
        script += `    f${i}[${j}] = ${selector};\n`;
      });

      script += `        cut[${i}] = IDiamondCut.FacetCut({facetAddress: ${facetCut.facetAddress}, action: IDiamondCut.FacetCutAction.${facetCut.action}, functionSelectors: f${i}});
    `;
    });

    script += `
        vm.startBroadcast(_ownerAddress);
        nayms.diamondCut(cut, address(0), new bytes(0));
        vm.stopBroadcast();
    }
}
`;

    // Write the script to the S03UpgradeDiamond.s.sol file
    fs.writeFile(
      path.join(__dirname, "../script/deployment/S03UpgradeDiamond.s.sol"),
      script,
      (err) => {
        if (err) {
          console.error(`Error writing file to disk: ${err}`);
        } else {
          console.log(`Successfully wrote script to S03UpgradeDiamond.s.sol`);
        }
      }
    );
  }
});
