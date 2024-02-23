pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MiniExecFactory} from "src/MiniExec.sol";

// @OF: rename to DeployMiniExecFactory or something more explicit
contract MiniExecScript is Script {
    MiniExecFactory factory;

    function run() public {
        vm.broadcast();
        factory = new MiniExecFactory();
    }
}
