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

    constructor(address _creator) {
        creator = MiniExecFactory(_creator);
    }

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        if (msg.sender != ZKEVM_BRIDGE) revert MiniExec__InvalidSender();
        (address remoteOwner, uint32 remoteNetwork) = _metadata();
        if (originAddress != remoteOwner) revert MiniExec__InvalidRemoteSender();
        if (originNetwork != remoteNetwork) revert MiniExec__InvalidRemoteNetwork();

        (address to, uint256 value, bytes memory cd) = abi.decode(data, (address, uint256, bytes));
        (bool success, bytes memory ret) = payable(to).call{value: value}(cd);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

    function _metadata() internal view returns (address, uint32) {
        return creator.metadata(address(this));
    }
}

contract MiniExecProxy is Proxy {
    error OnlySelf();

    MiniExecFactory immutable creator;

    constructor() {
        creator = MiniExecFactory(msg.sender);
    }

    function updateImplementation(address _newImplementation) external onlySelf {
        creator.setImplementation(_newImplementation);
    }

    function _implementation() internal view override returns (address) {
        return creator.implementations(address(this));
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    receive() external payable {
        _fallback();
    }
}

contract MiniExecFactory {
    struct Metadata {
        address owner;
        uint32 networkId;
    }

    mapping(address => Metadata) public metadata;
    mapping(address => address) public implementations;

    MiniExecImplementation public immutable miniExecImplementation;

    constructor() {
        miniExecImplementation = new MiniExecImplementation(address(this));
    }

    function createAccount(address _owner, uint32 _networkId) external returns (address) {
        MiniExecProxy proxy = new MiniExecProxy();
        metadata[address(proxy)] = Metadata({owner: _owner, networkId: _networkId});
        implementations[address(proxy)] = address(miniExecImplementation);
        return address(proxy);
    }

    function setImplementation(address _newImplementation) external {
        implementations[msg.sender] = _newImplementation;
    }
}
