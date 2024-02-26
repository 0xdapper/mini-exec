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
    error AlreadyInitialized();

    bool initialized;

    function initialize(address owner, uint32 networkId, address impl) external {
        if (initialized) revert AlreadyInitialized();

        remoteOwner = owner;
        remoteNetwork = networkId;
        implementation = impl;
        initialized = true;
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
    error OnlyOwner();
    error ZeroAddress();

    event OwnerChanged(address indexed _newOwner);
    event ImplementationChanged(address indexed _newImplementation);
    event AccountCreated(address indexed _owner, address indexed _account, uint32 _network);

    address public miniExecImplementation;
    address public owner;

    constructor() {
        miniExecImplementation = address(new MiniExecImplementation());
        owner = msg.sender;
        emit OwnerChanged(msg.sender);
        emit ImplementationChanged(miniExecImplementation);
    }

    function createAccount(address _owner, uint32 _networkId) external returns (address) {
        MiniExecProxy account = new MiniExecProxy();
        account.initialize(_owner, _networkId, miniExecImplementation);
        emit AccountCreated(_owner, address(account), _networkId);
        return address(account);
    }

    function setOwner(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        owner = _newOwner;
        emit OwnerChanged(_newOwner);
    }

    function changeImplementation(address _newImplementation) external onlyOwner {
        if (_newImplementation == address(0)) revert ZeroAddress();
        miniExecImplementation = _newImplementation;
        emit ImplementationChanged(_newImplementation);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }
}
