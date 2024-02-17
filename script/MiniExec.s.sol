import {Script} from "forge-std/Script.sol";
import {MiniExecFactory} from "src/MiniExec.sol";

contract MiniExecScript is Script {
    MiniExecFactory factory;

    function run() public {
        vm.broadcast();
        factory = new MiniExecFactory();
    }
}
