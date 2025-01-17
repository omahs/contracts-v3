// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "script/utils/DeploymentHelpers.sol";

contract S02ScheduleUpgrade is DeploymentHelpers {
    function run(address _systemAdminAddress, bytes32 upgradeHash) external {
        INayms nayms = INayms(getDiamondAddressFromFile());

        vm.startBroadcast(_systemAdminAddress);
        nayms.createUpgrade(upgradeHash);
        vm.stopBroadcast();
    }
}
