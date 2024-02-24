pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployMiniExecFactoryScript} from "script/MiniExec.s.sol";
import {MiniExecProxy, MiniExecImplementation, MiniExecFactory, ZKEVM_BRIDGE} from "src/MiniExec.sol";

contract AnotherImplementation {
    error AlwaysReverts();

    function onMessageReceived(address, uint32, bytes calldata) external pure {
        revert AlwaysReverts();
    }
}

contract MockContract {
    uint256 public a;

    function increment() external {
        a += 1;
    }

    function decremenet() external {
        a -= 1;
    }

    function depositEth() external payable {}
}

contract MiniExecTest is Test, DeployMiniExecFactoryScript {
    MiniExecProxy account;
    address remoteOwner = makeAddr("remoteOwner");
    address remoteRando = makeAddr("remoteRando");
    uint32 remoteNetworkId = 1;

    function setUp() external {
        run();
        account = MiniExecProxy(payable(factory.createAccount(remoteOwner, remoteNetworkId)));
    }

    function testCallsCorrectly() external {
        MockContract mockContract = new MockContract();

        uint256 a = mockContract.a();
        _receiveMessage(
            remoteOwner,
            remoteNetworkId,
            abi.encode(address(mockContract), 0, abi.encodeCall(MockContract.increment, ())),
            0,
            true
        );
        assertEq(mockContract.a(), a + 1);

        _receiveMessage(
            remoteOwner,
            remoteNetworkId,
            abi.encode(address(mockContract), 0, abi.encodeCall(MockContract.decremenet, ())),
            0,
            true
        );
        assertEq(mockContract.a(), a);

        uint256 balBefore = address(mockContract).balance;
        vm.deal(address(account), 1 ether);
        _receiveMessage(
            remoteOwner,
            remoteNetworkId,
            abi.encode(address(mockContract), 0.5 ether, abi.encodeCall(MockContract.depositEth, ())),
            0,
            true
        );
        assertEq(address(account).balance, 0.5 ether);
        assertEq(address(mockContract).balance, balBefore + 0.5 ether);
    }

    function testCalldataEmptyRevert() external {
        vm.expectRevert(MiniExecImplementation.MiniExec__EmptyCalldata.selector);
        _receiveMessage(remoteOwner, remoteNetworkId, hex"", 0, true);
    }

    function testValidMiniExecSender() external {
        vm.expectCall(address(0x01), 0, hex"12");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x01), 0, hex"12"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidSender.selector);
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x01), 0, hex"12"), 0, false);
    }

    function testValidMiniExecRemoteSender() external {
        vm.deal(address(account), 1 ether);
        vm.expectCall(address(0x02), 0.1 ether, hex"34");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x02), 0.1 ether, hex"34"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidRemoteSender.selector);
        _receiveMessage(remoteRando, remoteNetworkId, abi.encode(address(0x02), 0.1 ether, hex"34"), 0, true);
    }

    function testValidExecRemoteNetworkId() external {
        vm.expectCall(address(0x03), 0, hex"56");
        _receiveMessage(remoteOwner, remoteNetworkId, abi.encode(address(0x03), 0, hex"56"), 0, true);

        vm.expectRevert(MiniExecImplementation.MiniExec__InvalidRemoteNetwork.selector);
        _receiveMessage(remoteOwner, remoteNetworkId + 1, abi.encode(address(0x03), 0, hex"34"), 0, true);
    }

    function testValidMiniExecUpdate() external {
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
