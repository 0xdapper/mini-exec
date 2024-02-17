# Mini-Exec

A minimal smart contract wallet that can be operated from remote chain using
Polygon LxLy Bridge.

## Implementation

1. `MiniExecImplementation` -- the main implementation contract that will receive messages from LxLy bridge, validate that they are from correct owner, correct network and correct bridge contract. The metadata i.e. `remoteOwner` and `remoteNetworkId` is stored in the `MiniExecFactory` contract and is queried before validating the callback.
2. `MiniExecProxy` -- A simple upgradable proxy that gets its implementation address from `MiniExecFactory`. It can only be upgraded if it itself calls `updateImplementation`, i.e. the call itself needs to come from the remote owner and network via the LxLy bridge.
3. `MiniExecFactory` -- Factory contract for people to create accounts. Accounts are created as upgradable proxies i.e. `MiniExecProxy`. It also stores account metadata like `owner` and `networkId`. This metadata is immutable. It also stores the current implementation address for all the account proxies.
