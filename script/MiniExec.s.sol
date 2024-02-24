pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MiniExecFactory} from "src/MiniExec.sol";

contract DeployMiniExecFactoryScript is Script {
    MiniExecFactory factory;

    function run() public {
        vm.broadcast();
        factory = new MiniExecFactory();
    }
}
