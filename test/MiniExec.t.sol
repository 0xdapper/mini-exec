import {Test} from "forge-std/Test.sol";
import {MiniExecScript} from "script/MiniExec.s.sol";
import {MiniExecProxy, MiniExecImplementation, MiniExecFactory, ZKEVM_BRIDGE} from "src/MiniExec.sol";

contract AnotherImplementation {
    error AlwaysReverts();

    function onMessageReceived(address, uint32, bytes calldata) external pure {
        revert AlwaysReverts();
    }
}

contract MiniExecTest is Test, MiniExecScript {
    MiniExecProxy account;
    address remoteOwner = makeAddr("remoteOwner");
    address remoteRando = makeAddr("remoteRando");
    uint32 remoteNetworkId = 1;

    function setUp() external {
        run();
        account = MiniExecProxy(payable(factory.createAccount(remoteOwner, remoteNetworkId)));
    }

    function testMiniExecSender() external {
        vm.expectCall(address(0x01), 0, hex"12");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x01), 0, hex"12"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidSender.selector);
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x01), 0, hex"12"), 0, false);
    }

    function testMiniExecRemoteSender() external {
        vm.deal(address(account), 1 ether);
        vm.expectCall(address(0x02), 0.1 ether, hex"34");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x02), 0.1 ether, hex"34"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidRemoteSender.selector);
        _receiveMessage(remoteRando, remoteNetworkId, abi.encode(address(0x02), 0.1 ether, hex"34"), 0, true);
    }

    function testMiniExecRemoteNetworkId() external {
        vm.expectCall(address(0x03), 0, hex"56");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x03), 0, hex"56"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidRemoteNetwork.selector);
        _receiveMessage(remoteOwner, remoteNetworkId + 1, abi.encode(address(0x03), 0, hex"34"), 0, true);
    }

    function testMiniExecUpdate() external {
        AnotherImplementation anotherImplementation = new AnotherImplementation();

        vm.expectRevert(MiniExecProxy.OnlySelf.selector);
        vm.prank(remoteOwner);
        account.updateImplementation(address(anotherImplementation));

        _receiveMessage(
            remoteOwner,
            remoteNetworkId,
            abi.encode(
                address(account),
                0,
                abi.encodeCall(MiniExecProxy.updateImplementation, (address(anotherImplementation)))
            ),
            0,
            true
        );
        assertEq(
            factory.implementations(address(account)),
            address(anotherImplementation),
            "update implementation didnt work"
        );

        vm.expectRevert(AnotherImplementation.AlwaysReverts.selector);
        _receiveMessage(remoteOwner, remoteNetworkId, hex"", 0, true);
    }

    function _receiveMessage(address _sender, uint32 _networkId, bytes memory _data, uint256 _value, bool _shouldPrank)
        internal
    {
        if (_shouldPrank) vm.prank(ZKEVM_BRIDGE);
        MiniExecImplementation(address(account)).onMessageReceived{value: _value}(_sender, _networkId, _data);
    }
}
