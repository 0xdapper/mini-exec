pragma solidity ^0.8.24;

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";

interface IZkEVMBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable;
}

address constant ZKEVM_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

contract MiniExecImplementation is IZkEVMBridgeMessageReceiver {
    error MiniExec__InvalidRemoteSender();
    error MiniExec__InvalidRemoteNetwork();
    error MiniExec__InvalidSender();

    MiniExecFactory immutable creator;

    // @OF: spec says "Constructor takes in tuple of address and chain ID"
    constructor(address _creator) {
        creator = MiniExecFactory(_creator);
    }

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        if (msg.sender != ZKEVM_BRIDGE) revert MiniExec__InvalidSender();
        (address remoteOwner, uint32 remoteNetwork) = _metadata();
        if (originAddress != remoteOwner) revert MiniExec__InvalidRemoteSender();
        if (originNetwork != remoteNetwork) revert MiniExec__InvalidRemoteNetwork();
        // @OF: should it also check if calldata is empty?

        (address to, uint256 value, bytes memory cd) = abi.decode(data, (address, uint256, bytes));
        (bool success, bytes memory ret) = payable(to).call{value: value}(cd);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

    // @OF: see comment in constructor - that would avoid making a call to the factory
    // @OF: if this logic is kept, I think it's better to inline this?
    function _metadata() internal view returns (address, uint32) {
        return creator.metadata(address(this));
    }
}

contract MiniExecProxy is Proxy {
    error OnlySelf();

    MiniExecFactory immutable creator;

    // @OF: spec says "Constructor takes in tuple of address and chain ID"
    constructor() {
        creator = MiniExecFactory(msg.sender);
    }

    function updateImplementation(address _newImplementation) external onlySelf {
        creator.setImplementation(_newImplementation);
    }

    function _implementation() internal view override returns (address) {
        return creator.implementations(address(this));
    }

    // @OF: I would just inline the `if`, since the modifier is only used once
    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    // @OF: dont think this is needed, it will call `fallback` by default (which is payable)?
    // (I know that solc complains when there's a fallback but no receive)
    receive() external payable {
        _fallback();
    }
}

contract MiniExecFactory {
    struct Metadata {
        address owner;
        uint32 networkId;
    }

    mapping(address acctProxy => Metadata acctMetadata) public metadata;
    mapping(address acctProxy => address acctImpl) public implementations;

    MiniExecImplementation public immutable miniExecImplementation;

    constructor() {
        miniExecImplementation = new MiniExecImplementation(address(this));
    }

    function createAccount(address _owner, uint32 _networkId) external returns (address) {
        // @OF: suggestion
        address proxy = address(new MiniExecProxy()); 
        metadata[proxy] = Metadata({owner: _owner, networkId: _networkId});
        implementations[proxy] = address(miniExecImplementation);
        return proxy;
    }

    // @OF: there's no access control on this function, considering the logic, that's ok, but it allows anyone to spam this mapping
    // @OF: product question - should we be using the beacon proxy pattern (i.e. same implementation for all the proxies per network) or do we actually want every proxy to upgrade itself?
    function setImplementation(address _newImplementation) external {
        implementations[msg.sender] = _newImplementation;
    }
}
