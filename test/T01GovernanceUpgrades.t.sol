// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { D03ProtocolDefaults, console2, LibAdmin, LibConstants, LibHelpers, LibObject } from "./defaults/D03ProtocolDefaults.sol";
import { MockAccounts } from "test/utils/users/MockAccounts.sol";
import { LibACL } from "../src/diamonds/nayms/libs/LibACL.sol";
import { Entity } from "../src/diamonds/nayms/AppStorage.sol";
import "src/diamonds/nayms/interfaces/CustomErrors.sol";
import { IDiamondCut } from "src/diamonds/shared/interfaces/IDiamondCut.sol";
import { PhasedDiamondCutFacet, PhasedDiamondCutUpgradeFailed } from "src/diamonds/shared/facets/PhasedDiamondCutFacet.sol";

/// @dev Testing for Nayms upgrade pattern

contract TestFacet {
    function sayHello() external returns (string memory greeting) {
        greeting = "hello";
    }

    function sayHello2() external returns (string memory greeting) {
        greeting = "hello2";
    }
}

contract T01GovernanceUpgrades is D03ProtocolDefaults, MockAccounts {
    uint256 public constant STARTING_BLOCK_TIMESTAMP = 100;
    address public testFacetAddress;

    function setUp() public virtual override {
        super.setUp();

        // note: The diamond starts with the PhasedDiamondCutFacet insteaad of the original DiamondCutFacet

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        testFacetAddress = address(new TestFacet());
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        // warp so block.timestamp does not = 0, otherwise all upgrades will be "scheduled".
        vm.warp(STARTING_BLOCK_TIMESTAMP);
    }

    function testUnscheduledGovernanceUpgrade() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        // try to call diamondCut() without scheduling
        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        vm.expectRevert(abi.encodeWithSelector(PhasedDiamondCutUpgradeFailed.selector, upgradeId, block.timestamp));
        nayms.diamondCut(cut, address(0), "");
    }

    function testExpiredGovernanceUpgrade() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        vm.warp(7 days + STARTING_BLOCK_TIMESTAMP + 1);

        // try to call diamondCut() without scheduling
        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        vm.expectRevert(abi.encodeWithSelector(PhasedDiamondCutUpgradeFailed.selector, upgradeId, block.timestamp));
        nayms.diamondCut(cut, address(0), "");
    }

    function testGovernanceUpgrade() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));

        nayms.createUpgrade(upgradeId);
        changePrank(owner);
        nayms.diamondCut(cut, address(0), "");

        bytes memory call = abi.encodeCall(TestFacet.sayHello, ());

        (bool success, ) = address(nayms).call(call);
        assertTrue(success);
    }

    function testMustBeOwnerToDoAGovernanceUpgrade() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        nayms.createUpgrade(upgradeId);

        changePrank(address(0xAAAAAAAAA));
        vm.expectRevert("LibDiamond: Must be contract owner");
        nayms.diamondCut(cut, address(0), "");
    }

    function testCancelGovernanceUpgrade() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));

        vm.expectRevert("invalid upgrade ID");
        nayms.cancelUpgrade(upgradeId);

        nayms.createUpgrade(upgradeId);
        nayms.cancelUpgrade(upgradeId);

        // second step, call diamondCut()
        vm.expectRevert(abi.encodeWithSelector(PhasedDiamondCutUpgradeFailed.selector, upgradeId, block.timestamp));
        nayms.diamondCut(cut, address(0), "");
    }

    function testScheduleTheSameGovernanceUpgradeBeforeExpiration() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        nayms.createUpgrade(upgradeId);

        vm.expectRevert("Upgrade has already been scheduled");
        nayms.createUpgrade(upgradeId);

        vm.warp(7 days + STARTING_BLOCK_TIMESTAMP + 1);

        /// note: don't need to cancel an upgrade if it has already expired
        nayms.createUpgrade(upgradeId);
    }

    function testGovernanceUpgradeMultiple() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        nayms.createUpgrade(upgradeId);

        // cut in the method sayHello2()
        IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f1 = new bytes4[](1);
        f1[0] = TestFacet.sayHello2.selector;
        cut2[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f1 });

        bytes32 upgradeId2 = keccak256(abi.encode(cut2, address(0), ""));
        nayms.createUpgrade(upgradeId2);

        changePrank(owner);

        nayms.diamondCut(cut, address(0), "");

        nayms.diamondCut(cut2, address(0), "");
    }

    function testUpdateUpgradeExpiration() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f0 = new bytes4[](1);
        f0[0] = TestFacet.sayHello.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f0 });

        bytes32 upgradeId = keccak256(abi.encode(cut, address(0), ""));
        nayms.createUpgrade(upgradeId);

        changePrank(address(0xAAAAAAAAA));
        vm.expectRevert("not a system admin");
        nayms.updateUpgradeExpiration(1 days);

        changePrank(systemAdmin);

        vm.expectRevert("invalid upgrade expiration period");
        nayms.updateUpgradeExpiration(59);
        vm.expectRevert("invalid upgrade expiration period");
        nayms.updateUpgradeExpiration(1 weeks + 1);

        nayms.updateUpgradeExpiration(1 days);

        assertEq(block.timestamp + 7 days, nayms.getUpgrade(upgradeId));

        IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
        bytes4[] memory f1 = new bytes4[](1);
        f1[0] = TestFacet.sayHello2.selector;
        cut2[0] = IDiamondCut.FacetCut({ facetAddress: address(testFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: f1 });

        bytes32 upgradeId2 = keccak256(abi.encode(cut2, address(0), ""));
        nayms.createUpgrade(upgradeId2);
        assertEq(block.timestamp + 1 days, nayms.getUpgrade(upgradeId2));
    }
}
