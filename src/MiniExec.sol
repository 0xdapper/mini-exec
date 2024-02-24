pragma solidity ^0.8.24;

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";

interface IZkEVMBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable;
}

address constant ZKEVM_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

contract MiniExecStorage {
    address remoteOwner;
    uint32 remoteNetwork;
    address implementation;
}

contract MiniExecImplementation is MiniExecStorage, IZkEVMBridgeMessageReceiver {
    error MiniExec__InvalidRemoteSender();
    error MiniExec__InvalidRemoteNetwork();
    error MiniExec__InvalidSender();
    error MiniExec__EmptyCalldata();
    error MiniExec__AlreadyInitialized();

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        if (msg.sender != ZKEVM_BRIDGE) revert MiniExec__InvalidSender();
        if (originAddress != remoteOwner) revert MiniExec__InvalidRemoteSender();
        if (originNetwork != remoteNetwork) revert MiniExec__InvalidRemoteNetwork();
        if (data.length == 0) revert MiniExec__EmptyCalldata();

        (address to, uint256 value, bytes memory cd) = abi.decode(data, (address, uint256, bytes));
        (bool success, bytes memory ret) = payable(to).call{value: value}(cd);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

contract MiniExecProxy is Proxy, MiniExecStorage {
    error OnlySelf();

    MiniExecFactory immutable creator;

    constructor(address owner, uint32 networkId, address impl) {
        remoteOwner = owner;
        remoteNetwork = networkId;
        implementation = impl;
    }

    function updateImplementation(address _newImplementation) external {
        if (msg.sender != address(this)) revert OnlySelf();
        implementation = _newImplementation;
    }

    function _implementation() internal view override returns (address) {
        return implementation;
    }
}

contract MiniExecFactory {
    MiniExecImplementation public immutable miniExecImplementation;

    constructor() {
        miniExecImplementation = new MiniExecImplementation();
    }

    function createAccount(address _owner, uint32 _networkId) external returns (address) {
        return address(new MiniExecProxy(_owner, _networkId, address(miniExecImplementation)));
    }
}
